// hook/build.dart — build hook for dart_vips
//
// Runs at compile/build time (dart build, flutter build, dart run, dart test).
// NOT run at pub-get time or application start-up.
//
// This hook does two things:
//   1. Compiles src/dart_vips_ops.c (non-vararg libvips wrappers) into a
//      shared library and declares it as a bundled code asset.
//   2. On Windows: also downloads and bundles the prebuilt libvips DLLs.
//      On macOS/Linux: the system libvips is used (libdart_vips_ops links to it).

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart' as crypto show sha256;
import 'package:hooks/hooks.dart';

// ---------------------------------------------------------------------------
// Version pin and Windows download metadata
// ---------------------------------------------------------------------------

const _vipsVersion = '8.18.2';

// SHA-256 hashes of the Windows web-variant zip files.
// Generate: sha256sum vips-dev-x64-web-8.18.2.zip  (Linux/macOS)
//           (Get-FileHash vips-dev-x64-web-8.18.2.zip -Algorithm SHA256).Hash.ToLower() (PowerShell)
const _windowsSha256 = {
  'x64': 'REPLACE_WITH_REAL_SHA256_FOR_vips-dev-x64-web-$_vipsVersion.zip',
  'arm64': 'REPLACE_WITH_REAL_SHA256_FOR_vips-dev-arm64-web-$_vipsVersion.zip',
};

String _windowsZipUrl(Architecture arch) {
  final archTag = arch == Architecture.arm64 ? 'arm64' : 'x64';
  return 'https://github.com/libvips/build-win64-mxe/releases/download/'
      'v$_vipsVersion/vips-dev-$archTag-web-$_vipsVersion.zip';
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) return;

    final targetOS = input.config.code.targetOS;
    final targetArch = input.config.code.targetArchitecture;

    if (targetOS == OS.android ||
        targetOS == OS.iOS ||
        targetOS == OS.fuchsia) {
      throw UnsupportedError(
        'dart_vips does not support $targetOS in v0.1. '
        'Mobile support is planned for v0.2.',
      );
    }

    // Step 1: Compile our C wrapper into a shared library.
    await _compileCWrappers(input, output);

    // Step 2 (Windows only): Bundle the libvips DLLs.
    if (targetOS == OS.windows) {
      await _bundleWindowsDlls(input, output, targetArch);
    }
    // macOS/Linux: libvips is a system library; libdart_vips_ops.dylib/.so
    // was compiled with -lvips so it loads libvips automatically at runtime.
  });
}

// ---------------------------------------------------------------------------
// Step 1: Compile dart_vips_ops.c
// ---------------------------------------------------------------------------

Future<void> _compileCWrappers(
  BuildInput input,
  BuildOutputBuilder output,
) async {
  final targetOS = input.config.code.targetOS;
  final packageRoot = input.packageRoot.toFilePath();
  final outDir = input.outputDirectory.toFilePath();
  final srcFile = '$packageRoot/src/dart_vips_ops.c';

  if (targetOS == OS.macOS) {
    final outLib = '$outDir/libdart_vips_ops.dylib';
    final pkg = await _pkgConfig(['--cflags', '--libs', 'vips']);
    await _run('cc', [
      '-shared',
      '-fPIC',
      '-o', outLib,
      '-I', '$packageRoot/src',
      srcFile,
      ...pkg.split(' ').where((s) => s.isNotEmpty),
      '-install_name', '@rpath/libdart_vips_ops.dylib',
    ]);
    output.assets.code.add(CodeAsset(
      package: input.packageName,
      name: 'libdart_vips_ops.dylib',
      linkMode: DynamicLoadingBundled(),
      file: Uri.file(outLib),
    ));
    output.dependencies.add(Uri.file(srcFile));

  } else if (targetOS == OS.linux) {
    final outLib = '$outDir/libdart_vips_ops.so';
    final pkg = await _pkgConfig(['--cflags', '--libs', 'vips']);
    await _run('cc', [
      '-shared',
      '-fPIC',
      '-o', outLib,
      '-I', '$packageRoot/src',
      srcFile,
      ...pkg.split(' ').where((s) => s.isNotEmpty),
    ]);
    output.assets.code.add(CodeAsset(
      package: input.packageName,
      name: 'libdart_vips_ops.so',
      linkMode: DynamicLoadingBundled(),
      file: Uri.file(outLib),
    ));
    output.dependencies.add(Uri.file(srcFile));

  } else if (targetOS == OS.windows) {
    // On Windows the C wrappers are compiled using MSVC or clang-cl.
    // We skip separate compilation here and instead rely on the prebuilt
    // vips-dev-*-web-*.zip which ships all necessary DLLs.
    // A separate dart_vips_ops.dll is generated from the extracted SDK.
    // TODO: implement MSVC/clang-cl compilation for Windows in v0.2.
    stderr.writeln(
      '[dart_vips] Windows C wrapper compilation is not yet automated; '
      'using libvips DLLs from the prebuilt zip.',
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 (Windows): Download and bundle prebuilt libvips DLLs
// ---------------------------------------------------------------------------

Future<void> _bundleWindowsDlls(
  BuildInput input,
  BuildOutputBuilder output,
  Architecture targetArch,
) async {
  final archKey = targetArch == Architecture.arm64 ? 'arm64' : 'x64';
  final zipUrl = _windowsZipUrl(targetArch);
  final expectedSha256 = _windowsSha256[archKey]!;

  final downloadDir = Directory.fromUri(
    input.outputDirectoryShared.resolve('vips-$_vipsVersion-$archKey/'),
  );
  final zipFile = File.fromUri(
    downloadDir.uri.resolve('vips-dev-$archKey-web-$_vipsVersion.zip'),
  );
  final extractDir = Directory.fromUri(
    downloadDir.uri.resolve('extracted/'),
  );

  if (!zipFile.existsSync()) {
    downloadDir.createSync(recursive: true);
    stderr.writeln('[dart_vips] Downloading $zipUrl …');
    await _downloadFile(zipUrl, zipFile);
  }
  _verifySha256(zipFile, expectedSha256);

  if (!extractDir.existsSync()) {
    extractDir.createSync(recursive: true);
    stderr.writeln('[dart_vips] Extracting ${zipFile.path} …');
    final result = await Process.run('powershell', [
      '-NoProfile', '-NonInteractive', '-Command',
      'Expand-Archive -Force -LiteralPath "${zipFile.path}" '
          '-DestinationPath "${extractDir.path}"',
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell', [],
        'Expand-Archive failed:\n${result.stderr}',
        result.exitCode,
      );
    }
  }

  final binDir = Directory.fromUri(
    extractDir.uri.resolve('vips-dev-$archKey-web-$_vipsVersion/bin/'),
  );
  if (!binDir.existsSync()) {
    throw StateError('[dart_vips] DLL directory not found: ${binDir.path}');
  }

  final dlls = binDir.listSync().whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.dll'))
      .toList();
  if (dlls.isEmpty) {
    throw StateError('[dart_vips] No DLLs found in ${binDir.path}');
  }

  for (final dll in dlls) {
    final dllName = dll.uri.pathSegments.last;
    output.assets.code.add(CodeAsset(
      package: input.packageName,
      name: dllName,
      linkMode: DynamicLoadingBundled(),
      file: dll.uri,
    ));
  }
  output.dependencies.add(zipFile.uri);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _run(String exe, List<String> args) async {
  stderr.writeln('[dart_vips] $exe ${args.join(' ')}');
  final result = await Process.run(exe, args);
  if (result.exitCode != 0) {
    throw ProcessException(exe, args,
        '${result.stdout}\n${result.stderr}', result.exitCode);
  }
}

Future<String> _pkgConfig(List<String> args) async {
  final result = await Process.run('pkg-config', args);
  if (result.exitCode != 0) {
    throw StateError(
      '[dart_vips] pkg-config failed: ${result.stderr}\n'
      'Install libvips-dev:  sudo apt install libvips-dev',
    );
  }
  return (result.stdout as String).trim();
}

Future<void> _downloadFile(String url, File destination) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('Failed to download $url (HTTP ${response.statusCode})');
    }
    await response.pipe(destination.openWrite());
  } finally {
    client.close();
  }
}

void _verifySha256(File file, String expected) {
  final bytes = file.readAsBytesSync();
  final digest = crypto.sha256.convert(bytes).toString();
  if (digest != expected.toLowerCase()) {
    throw StateError(
      '[dart_vips] SHA-256 mismatch for ${file.path}.\n'
      '  Expected: $expected\n'
      '  Got:      $digest\n'
      'Delete the cached zip and retry, or update the hash in hook/build.dart.',
    );
  }
}
