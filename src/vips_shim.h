// Curated libvips header shim for ffigen.
// Only exposes the subset of the libvips API that dart_vips actually calls.
// This prevents GLib macro noise from polluting the generated bindings.
#include <vips/vips.h>
