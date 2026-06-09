// dart_vips example — CLI image processing
//
// Usage:  dart run example/example.dart <input> <output> [width]
//
// Example:
//   dart run example/example.dart photo.jpg thumb.jpg 300

import 'dart:io';

import 'package:dart_vips/dart_vips.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: example.dart <input> <output> [width]');
    exit(1);
  }

  final inputPath = args[0];
  final outputPath = args[1];
  final targetWidth = args.length >= 3 ? int.parse(args[2]) : 300;

  print('Loading $inputPath…');
  final image = VipsImage.fromFile(inputPath);
  print('  ${image.width}×${image.height} ${image.bands} bands');

  print('Thumbnailing to ${targetWidth}px wide…');
  final thumb = image.thumbnail(targetWidth);
  print('  → ${thumb.width}×${thumb.height}');

  print('Saving to $outputPath…');
  await thumb.toFile(outputPath);

  final outSize = File(outputPath).lengthSync();
  print('  Saved ${(outSize / 1024).toStringAsFixed(1)} KB');

  thumb.dispose();
  image.dispose();
  print('Done.');
}
