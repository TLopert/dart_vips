// Non-vararg C wrapper functions for dart_vips.
// These wrap libvips operations that take optional GObject properties via
// C varargs — which Dart FFI cannot express. Each wrapper function has a
// fully explicit, fixed signature that ffigen can bind directly.
//
// Build: compiled by hook/build.dart into libdart_vips_ops, then loaded
// alongside libvips at runtime.
#pragma once
#include <vips/vips.h>

#ifdef __cplusplus
extern "C" {
#endif

// ----- Load / Save --------------------------------------------------------

// vips_image_new_from_file with no extra vararg options (adds NULL sentinel)
VipsImage* dart_vips_image_new_from_file(const char* path);

// vips_image_write_to_file with no extra vararg options (adds NULL sentinel)
int dart_vips_image_write_to_file(VipsImage* in, const char* path);

// vips_image_new_from_buffer with no extra options
VipsImage* dart_vips_image_from_buffer(
    const void* buf, size_t len);

// vips_image_write_to_buffer with suffix string (e.g. ".jpg[Q=80,strip]")
int dart_vips_image_to_buffer(
    VipsImage* in,
    const char* suffix,
    void** buf,
    size_t* len);

// ----- Resize / Thumbnail -------------------------------------------------

// vips_thumbnail_image: width-only (height=0 means unlimited)
int dart_vips_thumbnail(
    VipsImage* in,
    VipsImage** out,
    int width,
    int height,
    VipsInteresting crop);

// vips_thumbnail_buffer: create thumbnail directly from encoded bytes
int dart_vips_thumbnail_buffer(
    const void* buf,
    size_t len,
    VipsImage** out,
    int width,
    int height,
    VipsInteresting crop);

// vips_resize with optional vertical scale (0 = same as hscale)
int dart_vips_resize(
    VipsImage* in,
    VipsImage** out,
    double hscale,
    double vscale);

// vips_reduce
int dart_vips_reduce(
    VipsImage* in,
    VipsImage** out,
    double hshrink,
    double vshrink);

// ----- Geometry -----------------------------------------------------------

// vips_crop / extract_area
int dart_vips_crop(
    VipsImage* in,
    VipsImage** out,
    int left, int top,
    int width, int height);

// vips_smartcrop
int dart_vips_smartcrop(
    VipsImage* in,
    VipsImage** out,
    int width, int height,
    VipsInteresting interesting);

// vips_embed
int dart_vips_embed(
    VipsImage* in,
    VipsImage** out,
    int x, int y,
    int width, int height,
    VipsExtend extend);

// vips_flip
int dart_vips_flip(
    VipsImage* in,
    VipsImage** out,
    VipsDirection direction);

// vips_rot (90° increments only)
int dart_vips_rot(
    VipsImage* in,
    VipsImage** out,
    VipsAngle angle);

// vips_similarity (arbitrary angle)
int dart_vips_similarity(
    VipsImage* in,
    VipsImage** out,
    double angle);

// vips_autorot
int dart_vips_autorot(
    VipsImage* in,
    VipsImage** out);

// vips_flatten with optional RGB background (r,g,b each 0–255)
int dart_vips_flatten(
    VipsImage* in,
    VipsImage** out,
    double bg_r, double bg_g, double bg_b);

// ----- Color --------------------------------------------------------------

// vips_colourspace
int dart_vips_colourspace(
    VipsImage* in,
    VipsImage** out,
    VipsInterpretation space);

// vips_icc_transform
int dart_vips_icc_transform(
    VipsImage* in,
    VipsImage** out,
    const char* output_profile);

// ----- Composite ----------------------------------------------------------

// vips_composite2
int dart_vips_composite2(
    VipsImage* base,
    VipsImage* overlay,
    VipsImage** out,
    VipsBlendMode mode,
    int x, int y);

// ----- GObject lifecycle (wrapped so ffigen picks them up) ----------------

// These are already in the libvips dynamic library; we expose them via wrapper
// declarations so ffigen includes them without needing GLib in include-directives.
void dart_g_object_ref(VipsImage* obj);
void dart_g_object_unref(VipsImage* obj);
void dart_g_free(void* mem);

// Legacy unref helper (kept for backwards compat, prefer dart_vips_slot_finalizer).
void dart_vips_unref_void(void* obj);

// NativeFinalizer callback that owns a C-heap "slot".
// token must be a malloc'd Pointer<Pointer<Void>> whose value is the VipsImage*.
// Reads *slot, unrefs the VipsImage if non-null, then frees the slot.
// When dispose() is called first, the slot is zeroed, making this a safe no-op.
void dart_vips_slot_finalizer(void* slot);

// ----- Metadata -----------------------------------------------------------

// vips_image_get_int
int dart_vips_image_get_int(VipsImage* in, const char* name, int* out);
// vips_image_get_double
int dart_vips_image_get_double(VipsImage* in, const char* name, double* out);
// vips_image_set_int
void dart_vips_image_set_int(VipsImage* in, const char* name, int value);
// vips_image_set_double
void dart_vips_image_set_double(VipsImage* in, const char* name, double value);
// vips_image_set_string
void dart_vips_image_set_string(VipsImage* in, const char* name, const char* str);
// vips_image_remove — returns non-zero on success
int dart_vips_image_remove(VipsImage* in, const char* name);

// Returns 0 on success, fills *out with a newly-allocated string (caller must g_free).
int dart_vips_image_get_string(
    VipsImage* in,
    const char* name,
    char** out);

// vips_image_get_fields — returns NULL-terminated array of name strings.
// Each name is owned by libvips; do NOT free individual names, but DO
// call g_strfreev() on the returned array.
char** dart_vips_image_get_fields(VipsImage* in);

#ifdef __cplusplus
}
#endif
