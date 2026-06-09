// Tests run against a real libvips installation.
// Requires: brew install vips (macOS) or apt install libvips-dev (Linux).
//
// Run:  dart test

import 'dart:io';

import 'package:dart_vips/dart_vips.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

String fixture(String name) {
  // Use the script URI to find fixtures regardless of the working directory
  // set by the test runner. Platform.script may point to a .dill in a temp
  // dir, but the package root is always 3 levels up from test/vips_image_test.dart.
  // Resolve relative to the file that contains this helper.
  final here = Platform.script.toFilePath();
  // Walk up until we find a dir containing 'test/fixtures'.
  var dir = Directory(here).parent;
  for (var i = 0; i < 5; i++) {
    if (Directory('${dir.path}/test/fixtures').existsSync()) {
      return '${dir.path}/test/fixtures/$name';
    }
    dir = dir.parent;
  }
  // Fallback: assume dart test is run from the package root.
  return '${Directory.current.path}/test/fixtures/$name';
}

bool fixtureExists(String name) => File(fixture(name)).existsSync();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Ensure libvips initialises once before running tests.
  setUpAll(() {
    // Touch vipsLib to trigger lazy init; throws if libvips not found.
    expect(
      () => VipsImage.fromFile(fixture('sample.jpg')).dispose(),
      returnsNormally,
    );
  });

  group('VipsImage.fromFile', () {
    test('loads JPEG', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      expect(img.width, greaterThan(0));
      expect(img.height, greaterThan(0));
      expect(img.bands, equals(3));
    });

    test('loads PNG', () {
      if (!fixtureExists('sample.png')) return;
      final img = VipsImage.fromFile(fixture('sample.png'));
      addTearDown(img.dispose);
      expect(img.width, greaterThan(0));
    });

    test('loads WebP', () {
      if (!fixtureExists('sample.webp')) return;
      final img = VipsImage.fromFile(fixture('sample.webp'));
      addTearDown(img.dispose);
      expect(img.width, greaterThan(0));
    });

    test('throws VipsException for missing file', () {
      expect(
        () => VipsImage.fromFile('/nonexistent/missing.jpg'),
        throwsA(isA<VipsException>()),
      );
    });
  });

  group('VipsImage.fromBytes', () {
    test('round-trips a JPEG', () {
      final src = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(src.dispose);
      final bytes = src.toBytes('jpg');
      expect(bytes, isNotEmpty);
      final back = VipsImage.fromBytes(bytes);
      addTearDown(back.dispose);
      expect(back.width, equals(src.width));
      expect(back.height, equals(src.height));
    });
  });

  group('thumbnail', () {
    test('scales down to target width', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final thumb = img.thumbnail(150);
      addTearDown(thumb.dispose);
      expect(thumb.width, lessThanOrEqualTo(150));
      expect(thumb.height, greaterThan(0));
    });

    test('scales with height constraint', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final thumb = img.thumbnail(150, height: 150);
      addTearDown(thumb.dispose);
      expect(thumb.width, lessThanOrEqualTo(150));
      expect(thumb.height, lessThanOrEqualTo(150));
    });

    test('preserves aspect ratio', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final origAspect = img.width / img.height;
      // Use VipsInteresting.none to get an uncropped thumbnail that preserves
      // the original aspect ratio.
      final thumb = img.thumbnail(100, crop: VipsInteresting.none);
      addTearDown(thumb.dispose);
      final thumbAspect = thumb.width / thumb.height;
      expect(thumbAspect, closeTo(origAspect, 0.05));
    });
  });

  group('resize', () {
    test('scales to half', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final resized = img.resize(0.5);
      addTearDown(resized.dispose);
      expect(resized.width, closeTo(img.width * 0.5, 2));
      expect(resized.height, closeTo(img.height * 0.5, 2));
    });
  });

  group('crop', () {
    test('produces correct dimensions', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final cropped = img.crop(0, 0, 100, 80);
      addTearDown(cropped.dispose);
      expect(cropped.width, equals(100));
      expect(cropped.height, equals(80));
    });

    test('extractArea is an alias for crop', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final a = img.crop(10, 10, 50, 50);
      addTearDown(a.dispose);
      final b = img.extractArea(10, 10, 50, 50);
      addTearDown(b.dispose);
      expect(a.width, equals(b.width));
      expect(a.height, equals(b.height));
    });
  });

  group('flip', () {
    test('horizontal flip preserves dimensions', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final flipped = img.flip(VipsDirection.horizontal);
      addTearDown(flipped.dispose);
      expect(flipped.width, equals(img.width));
      expect(flipped.height, equals(img.height));
    });
  });

  group('rotate', () {
    test('90° swaps width and height', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final rotated = img.rotate(90);
      addTearDown(rotated.dispose);
      expect(rotated.width, equals(img.height));
      expect(rotated.height, equals(img.width));
    });

    test('180° preserves dimensions', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final rotated = img.rotate(180);
      addTearDown(rotated.dispose);
      expect(rotated.width, equals(img.width));
      expect(rotated.height, equals(img.height));
    });
  });

  group('colourspace', () {
    test('converts to greyscale (1 band)', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final grey = img.colourspace(VipsInterpretation.bW);
      addTearDown(grey.dispose);
      expect(grey.bands, equals(1));
    });

    test('keeps width and height', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final grey = img.colourspace(VipsInterpretation.bW);
      addTearDown(grey.dispose);
      expect(grey.width, equals(img.width));
      expect(grey.height, equals(img.height));
    });
  });

  group('embed', () {
    test('increases canvas size', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final embedded = img.embed(50, 50, img.width + 100, img.height + 100);
      addTearDown(embedded.dispose);
      expect(embedded.width, equals(img.width + 100));
      expect(embedded.height, equals(img.height + 100));
    });
  });

  group('toBytes', () {
    for (final format in ['jpg', 'png', 'webp']) {
      test('encodes to $format', () {
        final img = VipsImage.fromFile(fixture('sample.jpg'));
        addTearDown(img.dispose);
        final bytes = img.toBytes(format);
        expect(bytes.length, greaterThan(100));
      });
    }

    test('throws on unknown format', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      expect(() => img.toBytes('xyz'), throwsArgumentError);
    });
  });

  group('toFile', () {
    test('saves JPEG to disk', () async {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final out = fixture('../output_test.jpg');
      addTearDown(() => File(out).deleteSync(recursive: true));
      await img.toFile(out);
      expect(File(out).existsSync(), isTrue);
      expect(File(out).lengthSync(), greaterThan(0));
    });
  });

  group('metadata', () {
    test('listFields returns non-empty list', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      final fields = img.listFields();
      expect(fields, isNotEmpty);
    });

    test('setField / getField round-trip for int', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      img.setField('dart-vips-test', 42);
      expect(img.getField('dart-vips-test'), equals(42));
    });

    test('removeField returns true then getField returns null', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      addTearDown(img.dispose);
      img.setField('temp-key', 99);
      expect(img.removeField('temp-key'), isTrue);
      expect(img.getField('temp-key'), isNull);
    });
  });

  group('dispose', () {
    test('is idempotent', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      expect(() {
        img.dispose();
        img.dispose();
      }, returnsNormally);
    });

    test('throws StateError after dispose', () {
      final img = VipsImage.fromFile(fixture('sample.jpg'));
      img.dispose();
      expect(() => img.width, throwsStateError);
    });
  });

  group('avif / heif', () {
    test('loads AVIF if fixture present', () {
      if (!fixtureExists('sample.avif')) return;
      final img = VipsImage.fromFile(fixture('sample.avif'));
      addTearDown(img.dispose);
      expect(img.width, greaterThan(0));
    });

    test('loads HEIF if fixture present', () {
      if (!fixtureExists('sample.heif')) return;
      final img = VipsImage.fromFile(fixture('sample.heif'));
      addTearDown(img.dispose);
      expect(img.width, greaterThan(0));
    });
  });
}
