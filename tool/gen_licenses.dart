// Generates LICENSES.md from the bundled dependency manifest.
//
// Usage:  dart run tool/gen_licenses.dart
//
// The manifest is embedded below and lists every shared library bundled in
// the Windows web-variant zip (github.com/libvips/build-win64-mxe).
// macOS/Linux use system libraries — those are not distributed by dart_vips.

import 'dart:io';

const _preamble = '''# LICENSES.md

This file documents the open-source libraries bundled with dart_vips.

**Bundled libraries** are distributed only in the Windows web-variant prebuilt
zip from [github.com/libvips/build-win64-mxe](https://github.com/libvips/build-win64-mxe).
macOS and Linux users obtain libvips through their system package manager;
those libraries are not shipped by this package.

**License policy:** dart_vips bundles ONLY the "web" variant of the prebuilt
Windows binaries, which contains exclusively LGPL-2.1-or-later, MIT, and
BSD-licensed components. The GPL-encumbered "all" variant (which includes
fftw, poppler, and x265/HEVC) is **never** bundled.

dart_vips itself is licensed under the MIT License — see [LICENSE](LICENSE).

---

''';

// Dependency manifest — web-variant components.
// Sources: github.com/libvips/build-win64-mxe/tree/master/build
const _deps = [
  _Dep(
    name: 'libvips',
    version: '8.18.x',
    license: 'LGPL-2.1-or-later',
    url: 'https://github.com/libvips/libvips',
  ),
  _Dep(
    name: 'mozjpeg',
    version: '4.x',
    license: 'IJG / BSD-3-Clause / zlib',
    url: 'https://github.com/mozilla/mozjpeg',
  ),
  _Dep(
    name: 'libpng',
    version: '1.6.x',
    license: 'libpng',
    url: 'http://www.libpng.org/pub/png/libpng.html',
  ),
  _Dep(
    name: 'libwebp',
    version: '1.x',
    license: 'BSD-3-Clause',
    url: 'https://chromium.googlesource.com/webm/libwebp',
  ),
  _Dep(
    name: 'libaom (AV1/AVIF)',
    version: '3.x',
    license: 'BSD-2-Clause',
    url: 'https://aomedia.googlesource.com/aom',
  ),
  _Dep(
    name: 'libheif',
    version: '1.x',
    license: 'LGPL-3.0-or-later',
    url: 'https://github.com/strukturag/libheif',
  ),
  _Dep(
    name: 'libtiff',
    version: '4.x',
    license: 'libtiff / MIT-like',
    url: 'http://www.libtiff.org/',
  ),
  _Dep(
    name: 'CGIF (GIF)',
    version: '0.x',
    license: 'MIT',
    url: 'https://github.com/lecram/cgif',
  ),
  _Dep(
    name: 'GLib / GObject',
    version: '2.x',
    license: 'LGPL-2.1-or-later',
    url: 'https://gitlab.gnome.org/GNOME/glib',
  ),
  _Dep(
    name: 'zlib',
    version: '1.x',
    license: 'zlib',
    url: 'https://zlib.net/',
  ),
  _Dep(
    name: 'expat',
    version: '2.x',
    license: 'MIT',
    url: 'https://libexpat.github.io/',
  ),
];

class _Dep {
  final String name;
  final String version;
  final String license;
  final String url;
  const _Dep({
    required this.name,
    required this.version,
    required this.license,
    required this.url,
  });
}

void main() {
  final buf = StringBuffer(_preamble);
  buf.writeln('## Bundled Windows dependencies\n');
  buf.writeln('| Library | Version | License | Source |');
  buf.writeln('|---|---|---|---|');
  for (final dep in _deps) {
    buf.writeln(
      '| ${dep.name} | ${dep.version} | ${dep.license} | [source](${dep.url}) |',
    );
  }
  buf.writeln();
  buf.writeln('''## Not included

The following GPL-encumbered or patent-encumbered components are present in the
libvips "all" Windows variant but are **deliberately excluded** from dart_vips:

- **fftw** (GPL-2.0) — frequency-domain processing
- **poppler** (GPL-2.0) — PDF rasterisation
- **x265 / libde265** (GPL-2.0 / patent-encumbered) — HEVC/H.265 encoding

If your use-case requires these, you must obtain a separate libvips build and
link dynamically. Do not redistribute GPL libraries as part of an application
without complying with the GPL.
''');

  final output = File('LICENSES.md');
  output.writeAsStringSync(buf.toString());
  print('Generated ${output.path} (${output.lengthSync()} bytes)');
}
