// Memory leak stress test.
// Runs 1,000 load → thumbnail → encode → dispose cycles and asserts that
// RSS does not grow unboundedly.
//
// Run:  dart test test/memory_test.dart

import 'dart:io';

import 'package:dart_vips/dart_vips.dart';
import 'package:test/test.dart';

String fixture(String name) {
  var dir = Directory(Platform.script.toFilePath()).parent;
  for (var i = 0; i < 5; i++) {
    if (Directory('${dir.path}/test/fixtures').existsSync()) {
      return '${dir.path}/test/fixtures/$name';
    }
    dir = dir.parent;
  }
  return '${Directory.current.path}/test/fixtures/$name';
}

void main() {
  group('Memory stability', () {
    test('1,000 thumbnail cycles do not leak', () {
      const iterations = 1000;

      // Warm up: ensure initial allocations (JIT, libvips caches) settle.
      for (var i = 0; i < 20; i++) {
        final img = VipsImage.fromFile(fixture('sample.jpg'));
        final thumb = img.thumbnail(100);
        thumb.toBytes('jpg');
        thumb.dispose();
        img.dispose();
      }

      final rssBefore = ProcessInfo.currentRss;

      for (var i = 0; i < iterations; i++) {
        final img = VipsImage.fromFile(fixture('sample.jpg'));
        final thumb = img.thumbnail(100);
        thumb.toBytes('jpg');
        thumb.dispose();
        img.dispose();
      }

      final rssAfter = ProcessInfo.currentRss;

      // Allow up to 20 MB growth (JIT warm-up, libvips operation cache, GC
      // promotion) but flag anything bigger. Real leaks across 1,000 JPEG
      // cycles accumulate hundreds of MB — 20 MB is still a tight bound.
      const allowedGrowthBytes = 20 * 1024 * 1024;
      expect(
        rssAfter - rssBefore,
        lessThan(allowedGrowthBytes),
        reason: 'RSS grew by ${rssAfter - rssBefore} bytes over $iterations '
            'iterations — possible memory leak',
      );
    });

    test('dispose is idempotent and does not crash', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      img.dispose();
      expect(img.dispose, returnsNormally);
    });

    test('undisposed image does not crash immediately', () {
      // Create an image without disposing. For v0.1 the GC backstop is a
      // no-op, so this leaks native memory — but must NOT crash immediately.
      // A reliable NativeFinalizer backstop is planned for v0.2.
      void createAndAbandon() {
        // ignore: unused_local_variable
        final img = VipsImage.fromFile(fixture('sample.jpg'));
      }

      expect(createAndAbandon, returnsNormally);
    });
  });
}
