/// dart_vips — Fast image processing for Dart and Flutter via libvips FFI.
///
/// Supports desktop (Windows, macOS, Linux) and Dart server/CLI.
/// Mobile platforms throw [UnsupportedError] in v0.1.
///
/// Quick start:
/// ```dart
/// final image = VipsImage.fromFile('photo.jpg');
/// final thumb = image.thumbnail(300);
/// await thumb.toFile('thumb.jpg');
/// thumb.dispose();
/// image.dispose();
/// ```
library;

export 'src/enums.dart';
export 'src/errors.dart' show VipsException;
export 'src/vips_image.dart';
