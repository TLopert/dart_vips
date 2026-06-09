import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/libvips_bindings.dart' as b;
import 'enums.dart';
import 'errors.dart';
import 'library_loader.dart';
import 'memory.dart';

// Helpers to convert our public enums to the bindings (ffigen) enum types.
b.VipsInteresting _cvInteresting(VipsInteresting v) =>
    b.VipsInteresting.fromValue(v.value);
b.VipsInterpretation _cvInterpretation(VipsInterpretation v) =>
    b.VipsInterpretation.fromValue(v.value);
b.VipsBlendMode _cvBlendMode(VipsBlendMode v) =>
    b.VipsBlendMode.fromValue(v.value);
b.VipsDirection _cvDirection(VipsDirection v) =>
    b.VipsDirection.fromValue(v.value);
b.VipsAngle _cvAngle(VipsAngle v) => b.VipsAngle.fromValue(v.value);
b.VipsExtend _cvExtend(VipsExtend v) => b.VipsExtend.fromValue(v.value);

/// High-level, idiomatic Dart wrapper around a libvips `VipsImage*`.
///
/// **Ownership:** Every factory and operation returns a new [VipsImage] whose
/// ownership is transferred to the caller. Call [dispose] when done, or rely
/// on the [NativeFinalizer] backstop (GC may be delayed — prefer explicit
/// [dispose] in performance-sensitive code).
///
/// **Immutable-style ops:** All transform methods return a NEW [VipsImage];
/// the original is unchanged. Dispose both when finished.
///
/// **Isolate safety:** Never pass [VipsImage] across isolate boundaries (raw
/// native pointers are not serializable). Serialize with [toBytes] / [fromBytes]
/// or communicate via file paths.
final class VipsImage implements Finalizable {
  final Pointer<b.VipsImage> _ptr;
  bool _disposed = false;

  VipsImage._(this._ptr) {
    attachFinalizer(this, _ptr.cast<Void>());
  }

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  /// Loads an image from [path].
  /// Supports JPEG, PNG, WebP, AVIF, HEIF/HEIC, TIFF, GIF.
  factory VipsImage.fromFile(String path) {
    final lib = vipsLib;
    final pathPtr = path.toNativeUtf8();
    try {
      final ptr = lib.dart_vips_image_new_from_file(pathPtr.cast());
      if (ptr == nullptr) throwVipsError(lib, 'fromFile($path)');
      return VipsImage._(ptr);
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Decodes an image from encoded bytes in memory.
  factory VipsImage.fromBytes(Uint8List bytes) {
    final lib = vipsLib;
    final buf = bytesToNativeBuffer(bytes);
    try {
      final ptr = lib.dart_vips_image_from_buffer(buf.cast(), bytes.length);
      if (ptr == nullptr) throwVipsError(lib, 'fromBytes');
      return VipsImage._(ptr);
    } finally {
      malloc.free(buf);
    }
  }

  // ---------------------------------------------------------------------------
  // Properties
  // ---------------------------------------------------------------------------

  int get width {
    _checkNotDisposed();
    return _ptr.ref.Xsize;
  }

  int get height {
    _checkNotDisposed();
    return _ptr.ref.Ysize;
  }

  int get bands {
    _checkNotDisposed();
    return _ptr.ref.Bands;
  }

  VipsBandFormat get format {
    _checkNotDisposed();
    return VipsBandFormat.fromNative(_ptr.ref.BandFmtAsInt);
  }

  VipsInterpretation get interpretation {
    _checkNotDisposed();
    return VipsInterpretation.fromNative(_ptr.ref.TypeAsInt);
  }

  // ---------------------------------------------------------------------------
  // Output
  // ---------------------------------------------------------------------------

  /// Saves the image to [path]. Format is inferred from the file extension.
  /// Supported extensions: `.jpg`/`.jpeg`, `.png`, `.webp`, `.avif`,
  /// `.heif`/`.heic`, `.tiff`/`.tif`.
  Future<void> toFile(String path, {int quality = 80}) async {
    _checkNotDisposed();
    final lib = vipsLib;
    final suffix = _saveOptionsSuffix(path, quality);
    final pathWithOpts = '$path$suffix';
    final pathPtr = pathWithOpts.toNativeUtf8();
    try {
      final result = lib.dart_vips_image_write_to_file(_ptr, pathPtr.cast());
      if (result != 0) throwVipsError(lib, 'toFile($path)');
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Encodes the image to bytes.
  /// [format] is one of: `'jpg'`, `'jpeg'`, `'png'`, `'webp'`, `'avif'`,
  /// `'heif'`, `'heic'`, `'tiff'`, `'tif'`.
  Uint8List toBytes(String format, {int quality = 80}) {
    _checkNotDisposed();
    final lib = vipsLib;
    final suffix = _formatToSuffix(format, quality);
    final suffixPtr = suffix.toNativeUtf8();
    final outBuf = malloc<Pointer<Void>>();
    final outLen = malloc<IntPtr>();
    try {
      final result = lib.dart_vips_image_to_buffer(
        _ptr, suffixPtr.cast(), outBuf.cast(), outLen.cast(),
      );
      if (result != 0) throwVipsError(lib, 'toBytes($format)');
      return nativeBufferToBytes(lib, outBuf.value, outLen.value);
    } finally {
      malloc.free(suffixPtr);
      malloc.free(outBuf);
      malloc.free(outLen);
    }
  }

  // ---------------------------------------------------------------------------
  // Resize / Thumbnail
  // ---------------------------------------------------------------------------

  /// Generates a thumbnail no wider than [width] (and no taller than [height]
  /// if given). Uses libvips' fast shrink-on-load pipeline.
  VipsImage thumbnail(
    int width, {
    int? height,
    VipsInteresting crop = VipsInteresting.attention,
  }) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_thumbnail(
        _ptr, outPtr, width, height ?? 0, _cvInteresting(crop),
      );
      if (result != 0) throwVipsError(lib, 'thumbnail');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Resizes by [scale] factor. Values < 1 shrink; values > 1 enlarge.
  VipsImage resize(double scale, {double? vscale}) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_resize(_ptr, outPtr, scale, vscale ?? 0);
      if (result != 0) throwVipsError(lib, 'resize');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Shrinks by [hShrink] horizontally and [vShrink] vertically (both >= 1).
  VipsImage reduce(double hShrink, double vShrink) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_reduce(_ptr, outPtr, hShrink, vShrink);
      if (result != 0) throwVipsError(lib, 'reduce');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  // ---------------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------------

  /// Crops a [width]×[height] rectangle starting at ([left], [top]).
  VipsImage crop(int left, int top, int width, int height) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_crop(_ptr, outPtr, left, top, width, height);
      if (result != 0) throwVipsError(lib, 'crop');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Crops to [width]×[height] using content-aware smart focus.
  VipsImage smartcrop(
    int width,
    int height, {
    VipsInteresting interesting = VipsInteresting.attention,
  }) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_smartcrop(
        _ptr, outPtr, width, height, _cvInteresting(interesting),
      );
      if (result != 0) throwVipsError(lib, 'smartcrop');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Embeds this image in a [width]×[height] canvas at ([x], [y]).
  VipsImage embed(
    int x,
    int y,
    int width,
    int height, {
    VipsExtend extend = VipsExtend.black,
  }) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_embed(
        _ptr, outPtr, x, y, width, height, _cvExtend(extend),
      );
      if (result != 0) throwVipsError(lib, 'embed');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Extracts a [width]×[height] region at ([left], [top]). Alias for [crop].
  VipsImage extractArea(int left, int top, int width, int height) =>
      crop(left, top, width, height);

  /// Flips the image horizontally or vertically.
  VipsImage flip(VipsDirection direction) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_flip(_ptr, outPtr, _cvDirection(direction));
      if (result != 0) throwVipsError(lib, 'flip');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Rotates by [degrees]. 0, 90, 180, 270 are lossless; others use bilinear.
  VipsImage rotate(double degrees) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final int result;
      if (degrees == 90 || degrees == 180 || degrees == 270) {
        final angle = degrees == 90
            ? _cvAngle(VipsAngle.d90)
            : degrees == 180
                ? _cvAngle(VipsAngle.d180)
                : _cvAngle(VipsAngle.d270);
        result = lib.dart_vips_rot(_ptr, outPtr, angle);
      } else if (degrees == 0) {
        lib.dart_g_object_ref(_ptr);
        return VipsImage._(_ptr);
      } else {
        result = lib.dart_vips_similarity(_ptr, outPtr, degrees);
      }
      if (result != 0) throwVipsError(lib, 'rotate($degrees)');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Rotates the image according to the EXIF orientation tag, then strips it.
  VipsImage autorotate() {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_autorot(_ptr, outPtr);
      if (result != 0) throwVipsError(lib, 'autorotate');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Flattens transparency onto [background] (RGB, 0–255, default white).
  VipsImage flatten({List<double> background = const [255.0, 255.0, 255.0]}) {
    _checkNotDisposed();
    if (background.length != 3) {
      throw ArgumentError.value(
          background, 'background', 'must have exactly 3 elements');
    }
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_flatten(
        _ptr, outPtr, background[0], background[1], background[2],
      );
      if (result != 0) throwVipsError(lib, 'flatten');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  // ---------------------------------------------------------------------------
  // Color
  // ---------------------------------------------------------------------------

  /// Converts to the given colour space.
  VipsImage colourspace(VipsInterpretation space) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result =
          lib.dart_vips_colourspace(_ptr, outPtr, _cvInterpretation(space));
      if (result != 0) throwVipsError(lib, 'colourspace');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  /// Applies an ICC profile transform. [profilePath] must be an `.icc`/`.icm` file.
  VipsImage iccTransform(String profilePath) {
    _checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    final profilePtr = profilePath.toNativeUtf8();
    try {
      final result =
          lib.dart_vips_icc_transform(_ptr, outPtr, profilePtr.cast());
      if (result != 0) throwVipsError(lib, 'iccTransform');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
      malloc.free(profilePtr);
    }
  }

  // ---------------------------------------------------------------------------
  // Composite
  // ---------------------------------------------------------------------------

  /// Composites [overlay] on top of this image using [mode].
  /// ([x], [y]) is the top-left corner of the overlay.
  VipsImage composite(
    VipsImage overlay,
    VipsBlendMode mode, {
    int x = 0,
    int y = 0,
  }) {
    _checkNotDisposed();
    overlay._checkNotDisposed();
    final lib = vipsLib;
    final outPtr = malloc<Pointer<b.VipsImage>>();
    try {
      final result = lib.dart_vips_composite2(
        _ptr, overlay._ptr, outPtr, _cvBlendMode(mode), x, y,
      );
      if (result != 0) throwVipsError(lib, 'composite');
      return VipsImage._(outPtr.value);
    } finally {
      malloc.free(outPtr);
    }
  }

  // ---------------------------------------------------------------------------
  // Metadata
  // ---------------------------------------------------------------------------

  /// Gets a named metadata field. Returns [int], [double], or [String],
  /// or `null` if the field does not exist.
  Object? getField(String name) {
    _checkNotDisposed();
    final lib = vipsLib;
    final namePtr = name.toNativeUtf8();
    try {
      final intOut = malloc<Int>();
      try {
        if (lib.dart_vips_image_get_int(_ptr, namePtr.cast(), intOut) == 0) {
          return intOut.value;
        }
      } finally {
        malloc.free(intOut);
      }

      final dblOut = malloc<Double>();
      try {
        if (lib.dart_vips_image_get_double(_ptr, namePtr.cast(), dblOut) == 0) {
          return dblOut.value;
        }
      } finally {
        malloc.free(dblOut);
      }

      final strOut = malloc<Pointer<Char>>();
      try {
        if (lib.dart_vips_image_get_string(
                _ptr, namePtr.cast(), strOut.cast()) ==
            0) {
          final v = strOut.value.cast<Utf8>().toDartString();
          lib.dart_g_free(strOut.value.cast());
          return v;
        }
      } finally {
        malloc.free(strOut);
      }

      return null;
    } finally {
      malloc.free(namePtr);
    }
  }

  /// Sets a named metadata field. [value] must be [int], [double], or [String].
  void setField(String name, Object value) {
    _checkNotDisposed();
    final lib = vipsLib;
    final namePtr = name.toNativeUtf8();
    try {
      if (value is int) {
        lib.dart_vips_image_set_int(_ptr, namePtr.cast(), value);
      } else if (value is double) {
        lib.dart_vips_image_set_double(_ptr, namePtr.cast(), value);
      } else if (value is String) {
        final valPtr = value.toNativeUtf8();
        lib.dart_vips_image_set_string(_ptr, namePtr.cast(), valPtr.cast());
        malloc.free(valPtr);
      } else {
        throw ArgumentError.value(
            value, 'value', 'must be int, double, or String');
      }
    } finally {
      malloc.free(namePtr);
    }
  }

  /// Removes a named metadata field. Returns `true` if it existed.
  bool removeField(String name) {
    _checkNotDisposed();
    final lib = vipsLib;
    final namePtr = name.toNativeUtf8();
    try {
      return lib.dart_vips_image_remove(_ptr, namePtr.cast()) != 0;
    } finally {
      malloc.free(namePtr);
    }
  }

  /// Returns a list of all metadata field names.
  List<String> listFields() {
    _checkNotDisposed();
    final lib = vipsLib;
    final arr = lib.dart_vips_image_get_fields(_ptr);
    if (arr == nullptr) return const [];
    final result = <String>[];
    var i = 0;
    while (arr[i] != nullptr) {
      result.add(arr[i].cast<Utf8>().toDartString());
      i++;
    }
    for (var j = 0; j < result.length; j++) {
      lib.dart_g_free(arr[j].cast());
    }
    lib.dart_g_free(arr.cast());
    return result;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Releases the native VipsImage. Idempotent — safe to call multiple times.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    detachFinalizer(this);
    vipsLib.dart_g_object_unref(_ptr);
  }

  @override
  String toString() => 'VipsImage(${width}x$height, $bands bands, $format)';

  void _checkNotDisposed() {
    if (_disposed) throw StateError('VipsImage has been disposed');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static String _saveOptionsSuffix(String path, int quality) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'jpg' || 'jpeg' => '[Q=$quality,strip]',
      'png' => '[compression=6,strip]',
      'webp' => '[Q=$quality,strip]',
      'avif' => '[Q=$quality,strip]',
      'heif' || 'heic' => '[Q=$quality,strip]',
      'tiff' || 'tif' => '[compression=deflate]',
      _ => '',
    };
  }

  static String _formatToSuffix(String format, int quality) {
    return switch (format.toLowerCase()) {
      'jpg' || 'jpeg' => '.jpg[Q=$quality,strip]',
      'png' => '.png[compression=6,strip]',
      'webp' => '.webp[Q=$quality,strip]',
      'avif' => '.avif[Q=$quality,strip]',
      'heif' || 'heic' => '.heif[Q=$quality,strip]',
      'tiff' || 'tif' => '.tiff[compression=deflate]',
      _ => throw ArgumentError.value(
          format, 'format',
          'Unsupported format. Use: jpg, png, webp, avif, heif, tiff'),
    };
  }
}
