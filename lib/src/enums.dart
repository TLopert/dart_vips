/// Smart-crop focus point used by [VipsImage.thumbnail] and [VipsImage.smartcrop].
enum VipsInteresting {
  none,
  centre,
  entropy,
  attention,
  low,
  high,
  all;

  int get value => switch (this) {
    VipsInteresting.none => 0,
    VipsInteresting.centre => 1,
    VipsInteresting.entropy => 2,
    VipsInteresting.attention => 3,
    VipsInteresting.low => 4,
    VipsInteresting.high => 5,
    VipsInteresting.all => 6,
  };

  static VipsInteresting fromNative(int v) => switch (v) {
    0 => none,
    1 => centre,
    2 => entropy,
    3 => attention,
    4 => low,
    5 => high,
    6 => all,
    _ => none,
  };
}

/// Colour space / interpretation.
enum VipsInterpretation {
  error,
  multiband,
  bW,
  histogram,
  xyz,
  lab,
  cmyk,
  labq,
  rgb,
  cmc,
  lch,
  labs,
  srgb,
  yxy,
  fourier,
  rgb16,
  grey16,
  matrix,
  scrgb,
  hsv,
  last;

  int get value => switch (this) {
    VipsInterpretation.error => -1,
    VipsInterpretation.multiband => 0,
    VipsInterpretation.bW => 1,
    VipsInterpretation.histogram => 10,
    VipsInterpretation.xyz => 12,
    VipsInterpretation.lab => 13,
    VipsInterpretation.cmyk => 15,
    VipsInterpretation.labq => 16,
    VipsInterpretation.rgb => 17,
    VipsInterpretation.cmc => 18,
    VipsInterpretation.lch => 19,
    VipsInterpretation.labs => 21,
    VipsInterpretation.srgb => 22,
    VipsInterpretation.yxy => 23,
    VipsInterpretation.fourier => 24,
    VipsInterpretation.rgb16 => 25,
    VipsInterpretation.grey16 => 26,
    VipsInterpretation.matrix => 27,
    VipsInterpretation.scrgb => 28,
    VipsInterpretation.hsv => 29,
    VipsInterpretation.last => 30,
  };

  static VipsInterpretation fromNative(int v) {
    for (final e in VipsInterpretation.values) {
      if (e.value == v) return e;
    }
    return VipsInterpretation.error;
  }
}

/// Blend modes for [VipsImage.composite].
enum VipsBlendMode {
  clear,
  source,
  over,
  in_,
  out,
  atop,
  dest,
  destOver,
  destIn,
  destOut,
  destAtop,
  xor,
  add,
  saturate,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colourDodge,
  colourBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  last;

  int get value => index;

  static VipsBlendMode fromNative(int v) {
    if (v < 0 || v >= VipsBlendMode.values.length) return VipsBlendMode.over;
    return VipsBlendMode.values[v];
  }
}

/// Band format (pixel data type).
enum VipsBandFormat {
  notset,
  uchar,
  char_,
  ushort,
  short_,
  uint,
  int_,
  float_,
  complex,
  double_,
  dpcomplex,
  last;

  int get value => switch (this) {
    VipsBandFormat.notset => -1,
    VipsBandFormat.uchar => 0,
    VipsBandFormat.char_ => 1,
    VipsBandFormat.ushort => 2,
    VipsBandFormat.short_ => 3,
    VipsBandFormat.uint => 4,
    VipsBandFormat.int_ => 5,
    VipsBandFormat.float_ => 6,
    VipsBandFormat.complex => 7,
    VipsBandFormat.double_ => 8,
    VipsBandFormat.dpcomplex => 9,
    VipsBandFormat.last => 10,
  };

  static VipsBandFormat fromNative(int v) {
    for (final e in VipsBandFormat.values) {
      if (e.value == v) return e;
    }
    return VipsBandFormat.notset;
  }
}

/// Flip direction for [VipsImage.flip].
enum VipsDirection {
  horizontal,
  vertical,
  last;

  int get value => index;
}

/// Rotation angle for [VipsImage.rotate] (90° increments).
enum VipsAngle {
  d0,
  d90,
  d180,
  d270,
  last;

  int get value => index;
}

/// Extension/embed strategy for [VipsImage.embed].
enum VipsExtend {
  black,
  copy,
  repeat,
  mirror,
  white,
  background,
  last;

  int get value => index;
}
