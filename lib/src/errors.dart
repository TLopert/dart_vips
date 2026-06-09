import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'bindings/libvips_bindings.dart' as b;

/// Thrown when a libvips operation fails.
final class VipsException implements Exception {
  final String message;
  const VipsException(this.message);

  @override
  String toString() => 'VipsException: $message';
}

/// Reads the libvips error buffer, clears it, and returns the message.
String readAndClearVipsError(b.LibVipsOps lib) {
  final ptr = lib.vips_error_buffer();
  final message = ptr == nullptr
      ? 'unknown libvips error'
      : ptr.cast<Utf8>().toDartString();
  lib.vips_error_clear();
  return message.isEmpty ? 'unknown libvips error' : message;
}

/// Throws [VipsException] with the current libvips error, then clears the buffer.
Never throwVipsError(b.LibVipsOps lib, [String? prefix]) {
  final msg = readAndClearVipsError(lib);
  throw VipsException(prefix != null ? '$prefix: $msg' : msg);
}
