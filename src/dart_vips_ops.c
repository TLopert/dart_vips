// Non-vararg C wrappers for dart_vips.
// Dart FFI cannot express C varargs, so every libvips operation that accepts
// optional GObject keyword arguments gets a plain, fixed-signature wrapper here.
// ffigen generates Dart bindings from dart_vips_ops.h, not from libvips headers.
#include "dart_vips_ops.h"
#include <string.h>
#include <stdlib.h>

// Called automatically when this shared library is loaded by the OS.
// Ensures vips_init() runs before any Dart FFI call reaches libvips, regardless
// of whether Dart's lazy library_loader.dart has fired yet.  vips_init is
// idempotent so the subsequent call in _load() is a harmless no-op.
__attribute__((constructor))
static void dart_vips_ops_library_init(void) {
    vips_init("dart_vips");
}

// ----- Load / Save -------------------------------------------------------

VipsImage* dart_vips_image_new_from_file(const char* path) {
    return vips_image_new_from_file(path, NULL);
}

int dart_vips_image_write_to_file(VipsImage* in, const char* path) {
    return vips_image_write_to_file(in, path, NULL);
}

VipsImage* dart_vips_image_from_buffer(const void* buf, size_t len) {
    return vips_image_new_from_buffer(buf, len, "", NULL);
}

int dart_vips_image_to_buffer(
    VipsImage* in,
    const char* suffix,
    void** buf,
    size_t* len)
{
    return vips_image_write_to_buffer(in, suffix, buf, len, NULL);
}

// ----- Resize / Thumbnail ------------------------------------------------

int dart_vips_thumbnail(
    VipsImage* in,
    VipsImage** out,
    int width,
    int height,
    VipsInteresting crop)
{
    if (height > 0) {
        return vips_thumbnail_image(in, out, width,
            "height", height,
            "crop",   crop,
            NULL);
    }
    return vips_thumbnail_image(in, out, width,
        "crop", crop,
        NULL);
}

int dart_vips_thumbnail_buffer(
    const void* buf,
    size_t len,
    VipsImage** out,
    int width,
    int height,
    VipsInteresting crop)
{
    if (height > 0) {
        return vips_thumbnail_buffer((void*)buf, len, out, width,
            "height", height,
            "crop",   crop,
            NULL);
    }
    return vips_thumbnail_buffer((void*)buf, len, out, width,
        "crop", crop,
        NULL);
}

int dart_vips_resize(
    VipsImage* in,
    VipsImage** out,
    double hscale,
    double vscale)
{
    if (vscale > 0 && vscale != hscale) {
        return vips_resize(in, out, hscale,
            "vscale", vscale,
            NULL);
    }
    return vips_resize(in, out, hscale, NULL);
}

int dart_vips_reduce(
    VipsImage* in,
    VipsImage** out,
    double hshrink,
    double vshrink)
{
    return vips_reduce(in, out, hshrink, vshrink, NULL);
}

// ----- Geometry ----------------------------------------------------------

int dart_vips_crop(
    VipsImage* in,
    VipsImage** out,
    int left, int top,
    int width, int height)
{
    return vips_crop(in, out, left, top, width, height, NULL);
}

int dart_vips_smartcrop(
    VipsImage* in,
    VipsImage** out,
    int width, int height,
    VipsInteresting interesting)
{
    return vips_smartcrop(in, out, width, height,
        "interesting", interesting,
        NULL);
}

int dart_vips_embed(
    VipsImage* in,
    VipsImage** out,
    int x, int y,
    int width, int height,
    VipsExtend extend)
{
    return vips_embed(in, out, x, y, width, height,
        "extend", extend,
        NULL);
}

int dart_vips_flip(
    VipsImage* in,
    VipsImage** out,
    VipsDirection direction)
{
    return vips_flip(in, out, direction, NULL);
}

int dart_vips_rot(
    VipsImage* in,
    VipsImage** out,
    VipsAngle angle)
{
    return vips_rot(in, out, angle, NULL);
}

int dart_vips_similarity(
    VipsImage* in,
    VipsImage** out,
    double angle)
{
    return vips_similarity(in, out,
        "angle", angle,
        NULL);
}

int dart_vips_autorot(VipsImage* in, VipsImage** out) {
    return vips_autorot(in, out, NULL);
}

int dart_vips_flatten(
    VipsImage* in,
    VipsImage** out,
    double bg_r, double bg_g, double bg_b)
{
    double bg[3] = { bg_r, bg_g, bg_b };
    VipsArrayDouble* arr = vips_array_double_new(bg, 3);
    int result = vips_flatten(in, out, "background", arr, NULL);
    g_object_unref(arr);
    return result;
}

// ----- Color -------------------------------------------------------------

int dart_vips_colourspace(
    VipsImage* in,
    VipsImage** out,
    VipsInterpretation space)
{
    return vips_colourspace(in, out, space, NULL);
}

int dart_vips_icc_transform(
    VipsImage* in,
    VipsImage** out,
    const char* output_profile)
{
    return vips_icc_transform(in, out, output_profile, NULL);
}

// ----- Composite ---------------------------------------------------------

int dart_vips_composite2(
    VipsImage* base,
    VipsImage* overlay,
    VipsImage** out,
    VipsBlendMode mode,
    int x, int y)
{
    return vips_composite2(base, overlay, out, mode,
        "x", x,
        "y", y,
        NULL);
}

// ----- GObject lifecycle -------------------------------------------------

void dart_g_object_ref(VipsImage* obj)  { g_object_ref(obj); }
void dart_g_object_unref(VipsImage* obj) { g_object_unref(obj); }
void dart_g_free(void* mem) { g_free(mem); }
void dart_vips_unref_void(void* obj) { if (obj) g_object_unref(obj); }

// Slot-based NativeFinalizer callback.
// slot points to a malloc'd region containing a GObject* (the VipsImage).
// We read the pointer, unref if non-null, then free the slot.
// If dispose() was called first it zeroed the slot — making this a no-op unref.
void dart_vips_slot_finalizer(void* slot) {
    GObject** s = (GObject**)slot;
    GObject* obj = *s;
    free(s);
    if (obj != NULL) g_object_unref(obj);
}

// ----- Metadata ----------------------------------------------------------

int dart_vips_image_get_int(VipsImage* in, const char* name, int* out) {
    return vips_image_get_int(in, name, out);
}
int dart_vips_image_get_double(VipsImage* in, const char* name, double* out) {
    return vips_image_get_double(in, name, out);
}
void dart_vips_image_set_int(VipsImage* in, const char* name, int value) {
    vips_image_set_int(in, name, value);
}
void dart_vips_image_set_double(VipsImage* in, const char* name, double value) {
    vips_image_set_double(in, name, value);
}
void dart_vips_image_set_string(VipsImage* in, const char* name, const char* str) {
    vips_image_set_string(in, name, str);
}
int dart_vips_image_remove(VipsImage* in, const char* name) {
    return vips_image_remove(in, name);
}

int dart_vips_image_get_string(
    VipsImage* in,
    const char* name,
    char** out)
{
    return vips_image_get_string(in, name, (const char**)out);
}

char** dart_vips_image_get_fields(VipsImage* in) {
    return vips_image_get_fields(in);
}
