import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/libvips_bindings.dart' as b;

// Finalizer note: Dart's Finalizer / NativeFinalizer in 3.10.x fires
// callbacks with corrupted token addresses during isolate shutdown and under
// the dart-test multi-isolate runner.  For v0.1 the backstop is disabled;
// explicit VipsImage.dispose() is required to release native memory.
// A reliable finalizer will be re-added in v0.2.

/// Registers [obj] for GC-backed cleanup (no-op for v0.1).
/// Explicit [VipsImage.dispose] is required to release native memory.
void attachFinalizer(Finalizable obj, Pointer<Void> imagePtr) {
  // no-op — see note above
}

/// Removes [obj] from GC-backed cleanup (no-op for v0.1).
void detachFinalizer(Finalizable obj) {
  // no-op — see note above
}

/// Copies [len] bytes from native [buf] into a Dart [Uint8List],
/// then calls [dart_g_free] on [buf].
Uint8List nativeBufferToBytes(b.LibVipsOps lib, Pointer<Void> buf, int len) {
  final result = Uint8List(len);
  result.setAll(0, buf.cast<Uint8>().asTypedList(len));
  lib.dart_g_free(buf);
  return result;
}

/// Allocates a native buffer and copies [bytes] into it.
/// Caller must free with [malloc.free].
Pointer<Uint8> bytesToNativeBuffer(Uint8List bytes) {
  final ptr = malloc.allocate<Uint8>(bytes.length);
  ptr.asTypedList(bytes.length).setAll(0, bytes);
  return ptr;
}
