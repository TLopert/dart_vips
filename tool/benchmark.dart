/// CLI benchmark: thumbnail + JPEG encode throughput.
///
/// Usage:
///   dart run tool/benchmark.dart [input.jpg] [iterations]
///
/// Defaults:
///   input      = test/fixtures/sample.jpg
///   iterations = 100
library;

import 'dart:io';

import 'package:dart_vips/dart_vips.dart';

void main(List<String> args) {
  final inputPath =
      args.isNotEmpty ? args[0] : 'test/fixtures/sample.jpg';
  final iterations =
      args.length >= 2 ? int.parse(args[1]) : 100;

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Error: input file not found: $inputPath');
    exit(1);
  }

  print('dart_vips benchmark');
  print('  input      : $inputPath');
  print('  iterations : $iterations');
  print('');

  // Load the source image once.
  final source = VipsImage.fromFile(inputPath);
  print('  source     : ${source.width}x${source.height}, ${source.bands} bands');

  // Warm-up: one run outside the timed loop so libvips caches are warm.
  {
    final w = source.thumbnail(300, crop: VipsInteresting.attention);
    w.toBytes('jpg');
    w.dispose();
  }

  // Timed loop.
  final sw = Stopwatch()..start();

  late int outWidth;
  late int outHeight;
  late int byteSize;

  for (var i = 0; i < iterations; i++) {
    final thumb = source.thumbnail(300, crop: VipsInteresting.attention);
    final bytes = thumb.toBytes('jpg');

    // Capture output stats on the last iteration.
    if (i == iterations - 1) {
      outWidth = thumb.width;
      outHeight = thumb.height;
      byteSize = bytes.length;
    }

    thumb.dispose();
  }

  sw.stop();

  source.dispose();

  final totalMs = sw.elapsedMilliseconds;
  final msPerImage = totalMs / iterations;
  final imagesPerSecond = 1000 / msPerImage;

  print('  output     : ${outWidth}x$outHeight, $byteSize bytes');
  print('');
  print('Results:');
  print('  iterations  : $iterations');
  print('  total time  : $totalMs ms');
  print('  ms / image  : ${msPerImage.toStringAsFixed(2)} ms');
  print('  images / s  : ${imagesPerSecond.toStringAsFixed(1)}');
}
