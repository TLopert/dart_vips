# dart_vips

Fast image processing for Dart and Flutter desktop/server via [libvips](https://www.libvips.org/) FFI.

libvips processes images without loading the whole image into memory — it is the engine behind Node.js
`sharp` (~270 M downloads/month). `dart_vips` brings the same performance to Dart CLI tools, Dart
servers, and Flutter desktop apps.

## Quick start

```dart
import 'package:dart_vips/dart_vips.dart';

Future<void> main() async {
  // Load
  final image = VipsImage.fromFile('photo.jpg');

  // Resize — thumbnail with attention-based smart crop to 300 px wide
  final thumb = image.thumbnail(300);

  // Composite — stamp a watermark PNG on top
  final watermark = VipsImage.fromFile('logo.png');
  final watermarked = thumb.composite(
    watermark,
    VipsBlendMode.over,
    x: 10,
    y: 10,
  );
  watermark.dispose();

  // Save
  await watermarked.toFile('out.webp', quality: 85);

  watermarked.dispose();
  thumb.dispose();
  image.dispose();
}
```

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  dart_vips: ^0.1.0
```

Then install libvips for your platform (see [Binary distribution](#binary-distribution) below).

## Supported operations

| Category | Method | Signature |
|---|---|---|
| **Load** | `fromFile` | `VipsImage.fromFile(String path)` |
| **Load** | `fromBytes` | `VipsImage.fromBytes(Uint8List bytes)` |
| **Save** | `toFile` | `toFile(String path, {int quality = 80})` |
| **Save** | `toBytes` | `toBytes(String format, {int quality = 80})` |
| **Properties** | `width` | `int get width` |
| **Properties** | `height` | `int get height` |
| **Properties** | `bands` | `int get bands` |
| **Properties** | `format` | `VipsBandFormat get format` |
| **Properties** | `interpretation` | `VipsInterpretation get interpretation` |
| **Thumbnail** | `thumbnail` | `thumbnail(int width, {int? height, VipsInteresting crop})` |
| **Resize** | `resize` | `resize(double scale, {double? vscale})` |
| **Resize** | `reduce` | `reduce(double hShrink, double vShrink)` |
| **Geometry** | `crop` | `crop(int left, int top, int width, int height)` |
| **Geometry** | `smartcrop` | `smartcrop(int width, int height, {VipsInteresting interesting})` |
| **Geometry** | `embed` | `embed(int x, int y, int width, int height, {VipsExtend extend})` |
| **Geometry** | `extractArea` | `extractArea(int left, int top, int width, int height)` |
| **Transform** | `flip` | `flip(VipsDirection direction)` |
| **Transform** | `rotate` | `rotate(double degrees)` |
| **Transform** | `autorotate` | `autorotate()` |
| **Transform** | `flatten` | `flatten({List<double> background})` |
| **Color** | `colourspace` | `colourspace(VipsInterpretation space)` |
| **Color** | `iccTransform` | `iccTransform(String profilePath)` |
| **Composite** | `composite` | `composite(VipsImage overlay, VipsBlendMode mode, {int x, int y})` |
| **Metadata** | `getField` | `getField(String name) → Object?` |
| **Metadata** | `setField` | `setField(String name, Object value)` |
| **Metadata** | `removeField` | `removeField(String name) → bool` |
| **Metadata** | `listFields` | `listFields() → List<String>` |
| **Lifecycle** | `dispose` | `dispose()` |

Supported save formats: `jpg`, `png`, `webp`, `avif`, `heif`/`heic`, `tiff`.

## Platform support

| Platform | Status | Notes |
|---|---|---|
| macOS (arm64 / x64) | Full support | `brew install vips` |
| Linux (x64 / arm64) | Full support | `apt install libvips-dev` |
| Windows (x64) | Full support | DLLs bundled automatically via build hooks |
| Android | v0.2 planned | `UnsupportedError` in v0.1 — see [libvips_ffi](https://pub.dev/packages/libvips_ffi) |
| iOS | v0.2 planned | `UnsupportedError` in v0.1 — see [libvips_ffi](https://pub.dev/packages/libvips_ffi) |

## Binary distribution

### Windows

The Windows `x64` DLLs come from the LGPL-clean **"web" variant** of
[build-win64-mxe](https://github.com/libvips/build-win64-mxe) and are bundled automatically
via `hook/build.dart` — no manual step is required on Dart 3.10+.

On older SDKs, run the one-time installer:

```sh
dart run dart_vips:install
```

**Build hook detail (Dart >= 3.10):** `hook/build.dart` runs automatically during
`dart run`, `dart test`, and `flutter build`. On Windows it downloads and caches the DLLs
alongside your compiled output so the package is fully self-contained.

### macOS

```sh
brew install vips
```

The build hook compiles the thin C wrapper and links it against the system libvips at build time.

### Linux (Debian / Ubuntu)

```sh
sudo apt install libvips-dev
```

Other distributions: install the `libvips` development package through your package manager
(e.g. `dnf install vips-devel` on Fedora, `pacman -S libvips` on Arch).

### What is never bundled

`dart_vips` **never ships GPL-encumbered codecs.** The following are always absent from the
Windows DLL set and are not required on any platform:

- `x265` / HEVC encoder (GPL)
- `fftw` (GPL)
- `poppler` (GPL)

The bundled dependency set is LGPL-2.1-or-later (libvips, GLib), MIT (CGIF),
BSD-2/3 (libwebp, libaom), and similar permissive licenses.
See [LICENSES.md](LICENSES.md) for the full list.

## dart_vips vs libvips_ffi

| | dart_vips | [libvips_ffi](https://pub.dev/packages/libvips_ffi) |
|---|---|---|
| Primary target | Desktop (Windows / macOS / Linux) and Dart servers | Mobile (Android / iOS) |
| libvips supply | System library (macOS / Linux) or bundled DLLs (Windows) | Ships its own static build |
| v0.1 mobile support | `UnsupportedError` | Full support |
| v0.2 mobile roadmap | Planned | Already supported |

Use `dart_vips` for Flutter desktop apps, Dart CLI tools, and backend servers.
Use `libvips_ffi` today if you need Android or iOS support.

## Performance

libvips is **internally threaded** — it automatically parallelises pipeline evaluation
across CPU cores without any extra work from your code.
Operations are safe to run inside `Isolate.run()`, provided you serialise the image
across the isolate boundary via `toBytes()` / `fromBytes()` (never pass a raw `VipsImage`
pointer between isolates):

```dart
final bytes = image.toBytes('webp');
final result = await Isolate.run(() {
  final img = VipsImage.fromBytes(bytes);
  final thumb = img.thumbnail(200);
  final out = thumb.toBytes('webp');
  thumb.dispose();
  img.dispose();
  return out;
});
```

## Memory management

Every `VipsImage` holds a GObject reference. Prefer explicit `.dispose()`:

```dart
final img = VipsImage.fromFile('photo.jpg');
try {
  final thumb = img.thumbnail(300);
  try {
    await thumb.toFile('out.jpg');
  } finally {
    thumb.dispose();
  }
} finally {
  img.dispose();
}
```

A `NativeFinalizer` is registered as a backstop so GC will eventually call
`g_object_unref` even if you forget — but in tight loops, explicit `dispose` is
critical for RSS stability and throughput.

## License

`dart_vips` itself is MIT licensed. See [LICENSE](LICENSE).

libvips is licensed **LGPL-2.1-or-later** and is always dynamically linked.
Your application is not subject to the LGPL so long as it does not modify or
statically embed libvips.

The Windows DLLs bundled by the build hook are from the LGPL-clean "web" variant of
[build-win64-mxe](https://github.com/libvips/build-win64-mxe).
See [LICENSES.md](LICENSES.md) for the full dependency license inventory.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
