# Third-Party Licenses

The dart_vips package itself is licensed under the **MIT License** (see `LICENSE`).

## Linking and Bundling Notes

dart_vips uses **dynamic linking only** for libvips and all its dependencies. No static linking is performed at any point. This approach is intentional and is the primary mechanism by which dart_vips complies with the LGPL licenses of its linked libraries — end users retain the ability to replace the shared libraries with their own builds.

On **Windows**, dart_vips ships prebuilt shared libraries from the official libvips "web" variant prebuilts. These prebuilts include the components documented below. On other platforms, libvips and its dependencies are expected to be installed separately by the user (e.g. via the system package manager), and no library files are bundled with the package.

---

## libvips

- License: LGPL-2.1-or-later
- Source: https://github.com/libvips/libvips
- Notes: The core image processing library. Dynamically linked on all platforms. On Windows, the shared library is bundled from the official libvips prebuilts.

## mozjpeg

- License: BSD-3-Clause AND IJG License
- Source: https://github.com/mozilla/mozjpeg
- Notes: JPEG encoder/decoder optimised for compression efficiency. The IJG License applies to portions derived from the Independent JPEG Group's original libjpeg code. Bundled on Windows as part of the libvips "web" prebuilts.

## libpng

- License: libpng License (permissive, similar to zlib)
- Source: http://www.libpng.org/pub/png/libpng.html
- Notes: PNG image format support. The libpng License is a permissive license authored by the libpng contributors. Bundled on Windows as part of the libvips "web" prebuilts.

## libwebp

- License: BSD-3-Clause
- Source: https://chromium.googlesource.com/webm/libwebp
- Notes: WebP image format encoder and decoder maintained by Google. Bundled on Windows as part of the libvips "web" prebuilts.

## libaom

- License: BSD-2-Clause
- Source: https://aomedia.googlesource.com/aom
- Notes: AV1 video/image codec reference implementation maintained by the Alliance for Open Media. Used for AVIF image support. Bundled on Windows as part of the libvips "web" prebuilts.

## libheif

- License: LGPL-3.0-or-later
- Source: https://github.com/strukturag/libheif
- Notes: HEIF/HEIC and AVIF container format support. Dynamically linked. Bundled on Windows as part of the libvips "web" prebuilts.

## libde265

- License: LGPL-3.0-or-later
- Source: https://github.com/strukturag/libde265
- Notes: H.265/HEVC decoder, used by libheif for HEIC image decoding. Dynamically linked. Bundled on Windows as part of the libvips "web" prebuilts.

## libtiff

- License: libtiff License (permissive, similar to BSD)
- Source: https://libtiff.gitlab.io/libtiff/
- Notes: TIFF image format support. The libtiff License is a permissive license maintained by the libtiff project. Bundled on Windows as part of the libvips "web" prebuilts.

## GLib / GObject

- License: LGPL-2.1-or-later
- Source: https://gitlab.gnome.org/GNOME/glib
- Notes: Core low-level system library and type system used internally by libvips. Dynamically linked. Bundled on Windows as part of the libvips "web" prebuilts.

## zlib

- License: zlib License (permissive)
- Source: https://zlib.net
- Notes: General-purpose compression library. Used by libpng and other components. The zlib License is a short permissive license authored by Jean-loup Gailly and Mark Adler. Bundled on Windows as part of the libvips "web" prebuilts.

## expat

- License: MIT
- Source: https://libexpat.github.io
- Notes: XML parser library used internally by various libvips dependencies. Bundled on Windows as part of the libvips "web" prebuilts.
