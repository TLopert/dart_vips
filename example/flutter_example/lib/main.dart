import 'dart:io';
import 'dart:typed_data';

import 'package:dart_vips/dart_vips.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DartVipsExampleApp());
}

class DartVipsExampleApp extends StatelessWidget {
  const DartVipsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dart_vips Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ImageProcessorPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// State

class _ImageResult {
  final Uint8List originalBytes;
  final int originalWidth;
  final int originalHeight;
  final String originalFormat;

  final Uint8List thumbBytes;
  final int thumbWidth;
  final int thumbHeight;

  const _ImageResult({
    required this.originalBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.originalFormat,
    required this.thumbBytes,
    required this.thumbWidth,
    required this.thumbHeight,
  });
}

// ---------------------------------------------------------------------------
// Page

class ImageProcessorPage extends StatefulWidget {
  const ImageProcessorPage({super.key});

  @override
  State<ImageProcessorPage> createState() => _ImageProcessorPageState();
}

class _ImageProcessorPageState extends State<ImageProcessorPage> {
  final _pathController = TextEditingController();
  bool _processing = false;
  String? _error;
  _ImageResult? _result;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Please enter an image path.');
      return;
    }
    if (!File(path).existsSync()) {
      setState(() => _error = 'File not found: $path');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });

    try {
      // All vips work is synchronous; run in an isolate via compute if needed
      // for large images, but for a demo this is fine on the main thread.
      final result = await _loadAndThumb(path);
      setState(() => _result = result);
    } on VipsException catch (e) {
      setState(() => _error = 'libvips error: $e');
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  static Future<_ImageResult> _loadAndThumb(String path) async {
    final image = VipsImage.fromFile(path);
    try {
      final thumb = image.thumbnail(300);
      try {
        final originalBytes = image.toBytes('png');
        final thumbBytes = thumb.toBytes('png');

        return _ImageResult(
          originalBytes: originalBytes,
          originalWidth: image.width,
          originalHeight: image.height,
          originalFormat: image.format.toString().split('.').last,
          thumbBytes: thumbBytes,
          thumbWidth: thumb.width,
          thumbHeight: thumb.height,
        );
      } finally {
        thumb.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('dart_vips Demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PathInputRow(
              controller: _pathController,
              onProcess: _processing ? null : _process,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              _ErrorBanner(message: _error!),
            if (_processing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_result != null)
              Expanded(child: _ResultView(result: _result!)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets

class _PathInputRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onProcess;

  const _PathInputRow({required this.controller, required this.onProcess});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Image path',
              hintText: '/path/to/image.jpg',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => onProcess?.call(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: onProcess,
          child: const Text('Process'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final _ImageResult result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ImageCard(
            label: 'Original',
            bytes: result.originalBytes,
            info: '${result.originalWidth} x ${result.originalHeight} px'
                '  |  ${result.originalFormat}',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _ImageCard(
            label: 'Thumbnail (300 px)',
            bytes: result.thumbBytes,
            info: '${result.thumbWidth} x ${result.thumbHeight} px',
          ),
        ),
      ],
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  final String info;

  const _ImageCard({
    required this.label,
    required this.bytes,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(info,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
