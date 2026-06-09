## 0.1.0

Initial release.

### Features

- **Load/save:** `VipsImage.fromFile`, `VipsImage.fromBytes`, `toFile`, `toBytes`
  - Formats: JPEG, PNG, WebP, AVIF, HEIF/HEIC, TIFF
- **Resize / thumbnail:** `thumbnail`, `resize`, `reduce`
- **Geometry:** `crop`, `smartcrop`, `embed`, `extractArea`, `flip`, `rotate`,
  `autorotate`, `flatten`
- **Color:** `colourspace`, `iccTransform`
- **Composite:** `composite` (blend modes)
- **Metadata:** `getField`, `setField`, `removeField`, `listFields`
- **Memory:** `NativeFinalizer` backstop + explicit `dispose()`
- **Platforms:** Windows (bundled web-variant DLLs via `dart run dart_vips:install`
  or build hook), macOS (system Homebrew), Linux (system apt/dnf)
- **Mobile:** throws `UnsupportedError` with a clear message (planned for v0.2)
- Dart build hook (`hook/build.dart`) for zero-setup with Dart ≥ 3.10

### License note

Windows DLLs bundled via the LGPL-clean "web" variant of
[build-win64-mxe](https://github.com/libvips/build-win64-mxe) only.
No GPL-encumbered codecs (fftw, poppler, x265) are ever distributed.
See [LICENSES.md](LICENSES.md).
