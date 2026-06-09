import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'bindings/libvips_bindings.dart' as b;
import 'errors.dart';

const _minMajor = 8;
const _minMinor = 15;
const _minPatch = 0;

b.LibVipsOps? _instance;
DynamicLibrary? _dl;

/// Returns the lazily-initialized, process-wide [LibVipsOps] instance.
///
/// Each isolate that calls this gets its own [DynamicLibrary] handle — that's
/// fine; libvips is internally threaded and safe to use concurrently.
b.LibVipsOps get vipsLib {
  return _instance ??= _load();
}

/// Returns the [DynamicLibrary] used to open libvips, needed by
/// [NativeFinalizer] to look up finalizer function pointers.
DynamicLibrary get vipsDl {
  if (_dl == null) _load();
  return _dl!;
}

b.LibVipsOps _load() {
  final dl = _openDynamicLibrary();
  final lib = b.LibVipsOps(dl);

  // Bootstrap libvips before any other call.
  final namePtr = 'dart_vips'.toNativeUtf8();
  try {
    final rc = lib.vips_init(namePtr.cast());
    if (rc != 0) throw VipsException('vips_init returned $rc');
  } finally {
    malloc.free(namePtr);
  }

  // Guard: require libvips >= 8.15.0 for AVIF/HEIF support.
  final major = lib.vips_version(0);
  final minor = lib.vips_version(1);
  final patch = lib.vips_version(2);
  final isOk = major > _minMajor ||
      (major == _minMajor && minor > _minMinor) ||
      (major == _minMajor && minor == _minMinor && patch >= _minPatch);
  if (!isOk) {
    throw VipsException(
      'libvips $major.$minor.$patch is too old. '
      'dart_vips requires >= $_minMajor.$_minMinor.$_minPatch.',
    );
  }

  _dl = dl;
  return lib;
}

DynamicLibrary _openDynamicLibrary() {
  if (Platform.isAndroid || Platform.isIOS) {
    throw UnsupportedError(
      'dart_vips does not support ${Platform.operatingSystem} in v0.1. '
      'Mobile support is planned for v0.2. '
      'For mobile image processing, see package:libvips_ffi.',
    );
  }

  // 1. Try opening by simple name — works when Dart's code asset system has
  //    set up DYLD_LIBRARY_PATH / LD_LIBRARY_PATH (dart test / dart run with
  //    DynamicLoadingBundled). Must be first to avoid duplicate loads.
  final assetName = _assetName();
  if (assetName != null) {
    try {
      return DynamicLibrary.open(assetName);
    } catch (_) {}
  }

  // 2. Env override — CI/Docker, or explicit path for development.
  final envPath = Platform.environment['DART_VIPS_LIB'];
  if (envPath != null && envPath.isNotEmpty) {
    return _tryOpen(envPath, 'DART_VIPS_LIB override');
  }

  // 3. Bundled library placed by hook/build.dart next to the executable.
  final bundled = _bundledPath();
  if (bundled != null) return _tryOpen(bundled, 'bundled (hook)');

  // 4. System fallback (no build hook, or Linux/macOS with system install).
  return _systemFallback();
}

String? _assetName() {
  if (Platform.isMacOS) return 'libdart_vips_ops.dylib';
  if (Platform.isLinux) return 'libdart_vips_ops.so';
  if (Platform.isWindows) return 'dart_vips_ops.dll';
  return null;
}

DynamicLibrary _systemFallback() {
  if (Platform.isLinux) {
    for (final name in ['libdart_vips_ops.so', 'libvips.so.42']) {
      try {
        return DynamicLibrary.open(name);
      } catch (_) {}
    }
    throw VipsException(
      'libvips not found on Linux.\n'
      'Install:  sudo apt install libvips-dev\n'
      'Then rebuild or run: dart run dart_vips:install',
    );
  }

  if (Platform.isMacOS) {
    for (final c in _macOsCandidates) {
      if (File(c).existsSync()) return _tryOpen(c, 'system (macOS)');
    }
    throw VipsException(
      'libvips not found on macOS.\n'
      'Install:  brew install vips\n'
      'Or set DART_VIPS_LIB=/path/to/libvips.dylib',
    );
  }

  if (Platform.isWindows) {
    throw VipsException(
      'libvips DLLs not found on Windows.\n'
      'Run:  dart run dart_vips:install',
    );
  }

  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

String? _bundledPath() {
  try {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final name = Platform.isLinux
        ? 'libdart_vips_ops.so'
        : Platform.isMacOS
            ? 'libdart_vips_ops.dylib'
            : Platform.isWindows
                ? 'dart_vips_ops.dll'
                : null;
    if (name == null) return null;
    final path = p.join(exeDir, name);
    if (File(path).existsSync()) return path;
  } catch (_) {}
  return null;
}

const _macOsCandidates = [
  '/opt/homebrew/lib/libvips.dylib',
  '/usr/local/lib/libvips.dylib',
  '/opt/local/lib/libvips.dylib',
];

DynamicLibrary _tryOpen(String path, String label) {
  try {
    return DynamicLibrary.open(path);
  } catch (e) {
    throw VipsException('Failed to load libvips from $label ($path): $e');
  }
}
