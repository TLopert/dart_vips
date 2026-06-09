// dart run dart_vips:install
//
// Manual setup CLI for environments where the build hook doesn't run
// (e.g. Docker build layers, CI without Dart SDK).
//
// Windows:  downloads the LGPL-clean web-variant zip from build-win64-mxe
//           and extracts the DLLs to a location alongside the Dart VM.
// macOS:    prints install instructions (brew install vips).
// Linux:    prints install instructions (apt / dnf / pacman).

import 'dart:io';
import 'package:crypto/crypto.dart' show sha256;
import 'package:path/path.dart' as p;

const _vipsVersion = '8.18.2';
const _repo = 'libvips/build-win64-mxe';

// SHA-256 hashes — update whenever you bump _vipsVersion.
const _sha256 = {
  'x64': 'REPLACE_WITH_REAL_SHA256_FOR_vips-dev-x64-web-$_vipsVersion.zip',
  'arm64': 'REPLACE_WITH_REAL_SHA256_FOR_vips-dev-arm64-web-$_vipsVersion.zip',
};

Future<void> main(List<String> args) async {
  final os = Platform.operatingSystem;

  if (Platform.isWindows) {
    await _installWindows();
  } else if (Platform.isMacOS) {
    _printMacOS();
  } else if (Platform.isLinux) {
    _printLinux();
  } else {
    stderr.writeln('dart_vips:install does not support $os.');
    stderr.writeln(
      'Mobile support (Android/iOS) is planned for v0.2. '
      'See package:libvips_ffi for mobile.',
    );
    exit(1);
  }
}

// ---------------------------------------------------------------------------
// Windows
// ---------------------------------------------------------------------------

Future<void> _installWindows() async {
  final arch = _windowsArch();
  final zipName = 'vips-dev-$arch-web-$_vipsVersion.zip';
  final url =
      'https://github.com/$_repo/releases/download/v$_vipsVersion/$zipName';

  // Install next to the Dart VM executable so it's on the default search path.
  final vmDir = p.dirname(Platform.resolvedExecutable);
  final destDir = Directory(p.join(vmDir, 'dart_vips_libs'));
  final zipFile = File(p.join(destDir.path, zipName));

  if (!destDir.existsSync()) destDir.createSync(recursive: true);

  // Check for existing installation.
  final vipsDll = File(p.join(destDir.path, 'bin', 'libvips-42.dll'));
  if (vipsDll.existsSync()) {
    print('dart_vips: libvips DLLs already installed at ${destDir.path}');
    print('Run with --force to re-download.');
    return;
  }

  print('dart_vips: Downloading libvips $arch web-variant from GitHub…');
  await _download(url, zipFile);

  final expectedHash = _sha256[arch]!;
  if (!expectedHash.startsWith('REPLACE_')) {
    _verifyHash(zipFile, expectedHash);
  } else {
    stderr.writeln(
      'WARNING: SHA-256 hash not configured in bin/install.dart. '
      'Skipping integrity check.',
    );
  }

  print('dart_vips: Extracting to ${destDir.path}…');
  final result = await Process.run('powershell', [
    '-NoProfile', '-NonInteractive', '-Command',
    'Expand-Archive -Force -LiteralPath "${zipFile.path}" '
        '-DestinationPath "${destDir.path}"',
  ]);
  if (result.exitCode != 0) {
    stderr.writeln('Extraction failed: ${result.stderr}');
    exit(1);
  }

  print('dart_vips: Installation complete.');
  print('DLLs are in: ${destDir.path}\\bin\\');
  print(
    'Set DART_VIPS_LIB=${p.join(destDir.path, 'bin', 'libvips-42.dll')} '
    'to use them.',
  );
}

String _windowsArch() {
  final cpu = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
  if (cpu.toUpperCase() == 'ARM64') return 'arm64';
  return 'x64';
}

// ---------------------------------------------------------------------------
// macOS
// ---------------------------------------------------------------------------

void _printMacOS() {
  print('''dart_vips: Install libvips via Homebrew:

  brew install vips

For Apple Silicon (M1/M2/M3):  /opt/homebrew/lib/libvips.dylib
For Intel Mac:                  /usr/local/lib/libvips.dylib

Verify installation:  vips --version

dart_vips will find libvips automatically after installation.
''');
}

// ---------------------------------------------------------------------------
// Linux
// ---------------------------------------------------------------------------

void _printLinux() {
  print('''dart_vips: Install libvips via your system package manager:

  Debian / Ubuntu:  sudo apt install libvips-dev
  Fedora / RHEL:    sudo dnf install vips-devel
  Alpine:           apk add vips-dev
  Arch:             sudo pacman -S libvips

After installation, verify:  vips --version

For Docker, add to your Dockerfile:
  FROM dart:stable
  RUN apt-get update && apt-get install -y libvips-dev && rm -rf /var/lib/apt/lists/*

dart_vips will find libvips automatically after installation.
''');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _download(String url, File dest) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) {
      stderr.writeln('HTTP ${res.statusCode} for $url');
      exit(1);
    }
    final sink = dest.openWrite();
    await res.pipe(sink);
  } finally {
    client.close();
  }
}

void _verifyHash(File file, String expected) {
  final bytes = file.readAsBytesSync();
  final actual = sha256.convert(bytes).toString();
  if (actual != expected.toLowerCase()) {
    stderr.writeln('SHA-256 mismatch for ${file.path}');
    stderr.writeln('Expected: $expected');
    stderr.writeln('Got:      $actual');
    file.deleteSync();
    exit(1);
  }
}
