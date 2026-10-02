import 'dart:math' as math;

/// How the output geometry is derived from the source image.
enum ResizeMode {
  original('Keep original'),
  longestSide('Fit inside box'),
  exactFit('Pad into box'),
  exactCrop('Crop to box'),
  exactStretch('Stretch to box'),
  width('Set width'),
  height('Set height'),
  percent('Scale by percent');

  const ResizeMode(this.label);

  final String label;

  /// True when the result is guaranteed to be exactly width x height.
  bool get isExact =>
      this == exactFit || this == exactCrop || this == exactStretch;
}

/// The pixel geometry of a result.
class TargetSize {
  const TargetSize(this.width, this.height);

  final int width;
  final int height;

  int get pixels => width * height;

  bool get isSquare => width == height;

  @override
  bool operator ==(Object other) =>
      other is TargetSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '$width x $height';
}

/// Resize parameters fed into [computeTargetSize].
class ResizeSpec {
  const ResizeSpec({
    this.mode = ResizeMode.longestSide,
    this.width,
    this.height,
    this.percent = 100,
    this.allowUpscale = false,
  });

  final ResizeMode mode;
  final int? width;
  final int? height;
  final int percent;
  final bool allowUpscale;

  ResizeSpec copyWith({
    ResizeMode? mode,
    int? width,
    int? height,
    int? percent,
    bool? allowUpscale,
  }) => ResizeSpec(
    mode: mode ?? this.mode,
    width: width ?? this.width,
    height: height ?? this.height,
    percent: percent ?? this.percent,
    allowUpscale: allowUpscale ?? this.allowUpscale,
  );
}

/// Geometry for modes that centre-crop or pad, expressed as source-pixel
/// rectangles to crop and canvas offsets.
class CropPlan {
  const CropPlan({
    this.cropX = 0,
    this.cropY = 0,
    this.cropW = 0,
    this.cropH = 0,
  });

  final int cropX;
  final int cropY;
  final int cropW;
  final int cropH;

  static const none = CropPlan();
}

int _clampDim(num v) {
  if (v.isNaN || v.isInfinite) return 1;
  final i = v.round();
  return i < 1 ? 1 : i;
}

/// Resolves [spec] against a source of [srcW] x [srcH] pixels.
TargetSize computeTargetSize(ResizeSpec spec, int srcW, int srcH) {
  if (srcW <= 0 || srcH <= 0) return const TargetSize(1, 1);

  final mode = spec.mode;

  if (mode == ResizeMode.original) {
    return TargetSize(srcW, srcH);
  }

  if (mode == ResizeMode.percent) {
    final p = (spec.percent.clamp(1, 1000)) / 100.0;
    if (!spec.allowUpscale && p >= 1.0) return TargetSize(srcW, srcH);
    return TargetSize(_clampDim(srcW * p), _clampDim(srcH * p));
  }

  if (mode == ResizeMode.width) {
    final w = spec.width ?? srcW;
    final scaled = w / srcW;
    final h = _clampDim(srcH * scaled);
    return _guardUpscale(spec, srcW, srcH, TargetSize(_clampDim(w), h));
  }

  if (mode == ResizeMode.height) {
    final h = spec.height ?? srcH;
    final scaled = h / srcH;
    final w = _clampDim(srcW * scaled);
    return _guardUpscale(spec, srcW, srcH, TargetSize(w, _clampDim(h)));
  }

  final boxW = math.max(1, spec.width ?? srcW);
  final boxH = math.max(1, spec.height ?? srcH);

  switch (mode) {
    case ResizeMode.exactStretch:
      return TargetSize(_clampDim(boxW), _clampDim(boxH));

    case ResizeMode.exactFit:
    case ResizeMode.exactCrop:
      // These modes promise an exact box, so the upscale guard does not apply:
      // padding or cropping is how the box is reached. A 400x400 source asked
      // for 600x600 exact-fit gets a 600x600 canvas.
      return TargetSize(_clampDim(boxW), _clampDim(boxH));

    case ResizeMode.longestSide:
    default:
      final scale = math.min(boxW / srcW, boxH / srcH);
      if (scale >= 1.0 && !spec.allowUpscale) {
        return TargetSize(srcW, srcH);
      }
      return TargetSize(_clampDim(srcW * scale), _clampDim(srcH * scale));
  }
}

/// The scaled size a "fit inside the box, then pad" pass should scale to.
/// This is the inner rectangle [computeTargetSize] does not return for
/// [ResizeMode.exactFit], because the outer canvas is the box itself.
TargetSize computeFitInsideBox(
  int srcW,
  int srcH,
  int boxW,
  int boxH, {
  bool allowUpscale = false,
}) {
  if (srcW <= 0 || srcH <= 0) return const TargetSize(1, 1);
  final bw = math.max(1, boxW);
  final bh = math.max(1, boxH);
  final scale = math.min(bw / srcW, bh / srcH);
  if (scale >= 1.0 && !allowUpscale) return TargetSize(srcW, srcH);
  return TargetSize(_clampDim(srcW * scale), _clampDim(srcH * scale));
}

TargetSize _guardUpscale(ResizeSpec spec, int srcW, int srcH, TargetSize t) {
  if (spec.allowUpscale) return t;
  if (t.width >= srcW && t.height >= srcH) return TargetSize(srcW, srcH);
  // Only block the axis that grew, keep the constraining one exact.
  var w = t.width;
  var h = t.height;
  if (w > srcW) {
    final k = srcW / w;
    w = srcW;
    h = _clampDim(h * k);
  }
  if (h > srcH) {
    final k = srcH / h;
    h = srcH;
    w = _clampDim(w * k);
  }
  return TargetSize(w, h);
}

/// Source-pixel crop needed to fill [target] at the source aspect ratio.
CropPlan computeCropPlan(int srcW, int srcH, TargetSize target) {
  if (srcW <= 0 || srcH <= 0) return CropPlan.none;
  if (target.width <= 0 || target.height <= 0) return CropPlan.none;

  final targetAspect = target.width / target.height;
  final srcAspect = srcW / srcH;

  int w;
  int h;
  if (srcAspect > targetAspect) {
    h = srcH;
    w = _clampDim(srcH * targetAspect);
  } else {
    w = srcW;
    h = _clampDim(srcW / targetAspect);
  }

  if (w >= srcW && h >= srcH) return CropPlan.none;

  final x = (srcW - w) ~/ 2;
  final y = (srcH - h) ~/ 2;
  return CropPlan(cropX: x, cropY: y, cropW: w, cropH: h);
}

/// Resampling method for a given downscale factor.
enum Resample { fast, balanced, high }

Resample defaultResample(int srcDim, int outDim) {
  final ratio = outDim <= 0 ? 1.0 : srcDim / outDim;
  if (ratio >= 3) return Resample.high;
  if (ratio >= 1.5) return Resample.balanced;
  return Resample.fast;
}
