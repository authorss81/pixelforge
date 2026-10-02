import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:image/image.dart' as img;

import 'job.dart';
import 'resize_mode.dart';
import 'settings.dart';

class EngineResult {
  const EngineResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.extension,
    this.quality,
    this.metTarget = true,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String extension;
  final int? quality;

  /// False when the requested byte budget could not be met at minimum quality.
  final bool metTarget;
}

class EngineError implements Exception {
  EngineError(this.message);

  final String message;

  @override
  String toString() => message;
}

class SourceInfo {
  const SourceInfo(this.width, this.height, this.format, this.extension);

  final int width;
  final int height;
  final String? format;
  final String? extension;
}

const List<num> _sharpenKernel = [0, -1, 0, -1, 5, -1, 0, -1, 0];

const List<String> supportedInputExtensions = <String>[
  'jpg',
  'jpeg',
  'jpe',
  'png',
  'webp',
  'gif',
  'tif',
  'tiff',
  'bmp',
  'ico',
  'tga',
  'psd',
  'pnm',
  'pvr',
  'exr',
  'heic',
  'heif',
  'avif',
];

const List<String> writeableExtensions = <String>[
  'jpg',
  'png',
  'webp',
  'gif',
  'tiff',
  'bmp',
];

/// Converts a Flutter colour to the codec library's channel colour.
img.Color toCodecColor(Color c) => img.ColorRgba8(
  (c.r * 255).round(),
  (c.g * 255).round(),
  (c.b * 255).round(),
  (c.a * 255).round(),
);

/// The pure-Dart image pipeline. No network, no platform channels.
class ResizeEngine {
  const ResizeEngine._();

  static String? extensionOf(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0 || i == path.length - 1) return null;
    return path.substring(i + 1).toLowerCase();
  }

  static String? extensionOfName(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return null;
    return name.substring(i + 1).toLowerCase();
  }

  /// Reads dimensions and container so the UI can show real numbers.
  static SourceInfo probe(Uint8List bytes, {String? name}) {
    final ext = name == null ? null : extensionOfName(name);
    final decoded = _decodeOrThrow(bytes, name);
    return SourceInfo(decoded.width, decoded.height, decoded.format.name, ext);
  }

  /// Decoders throw on malformed data rather than returning null, so every entry
  /// point funnels through here to give the UI one predictable error type.
  static img.Image _decodeOrThrow(Uint8List bytes, String? name) {
    img.Image? decoded;
    try {
      decoded = img.decodeNamedImage(name ?? '', bytes);
    } catch (e) {
      decoded = null;
    }
    if (decoded == null || !decoded.isValid) {
      throw EngineError(
        'Could not decode this file — unsupported or corrupt data. HEIC, HEIF '
        'and AVIF need the native codec build planned for v2; convert to JPEG first.',
      );
    }
    return decoded;
  }

  /// Full pipeline. [onProgress] receives 0..1 on a best-effort basis.
  static Future<EngineResult> run(
    Uint8List source,
    ResizeSettings s, {
    String? name,
    void Function(double)? onProgress,
  }) async {
    void tick(double v) => onProgress?.call(v.clamp(0.0, 1.0));

    tick(0.02);

    final decoded = _decodeOrThrow(source, name);

    tick(0.10);

    var work = decoded;

    // Orientation is always baked when metadata is being dropped, otherwise the
    // stripped orientation tag would leave the pixels sideways.
    if (work.exif.imageIfd.hasOrientation &&
        work.exif.imageIfd.orientation != 1) {
      work = img.bakeOrientation(work);
    }

    if (s.rotateQuarterTurns != 0) {
      work = img.copyRotate(work, angle: 90 * s.rotateQuarterTurns);
    }
    if (s.flipH) work = img.flipHorizontal(work);
    if (s.flipV) work = img.flipVertical(work);

    tick(0.22);

    final outFormat = _resolveFormat(
      s.format,
      s.keepExtensionWhenKeepFormat,
      name == null ? null : extensionOfName(name),
    );
    final spec = s.spec;

    // exactFit scales to sit inside the box and then pads out to it, so it needs
    // two sizes: the scaled inner rect and the outer canvas.
    final outer = computeTargetSize(spec, work.width, work.height);
    var target = spec.mode == ResizeMode.exactFit
        ? computeFitInsideBox(
            work.width,
            work.height,
            outer.width,
            outer.height,
            allowUpscale: spec.allowUpscale,
          )
        : outer;

    if (spec.mode == ResizeMode.exactCrop) {
      final plan = computeCropPlan(work.width, work.height, target);
      if (plan != CropPlan.none) {
        work = img.copyCrop(
          work,
          x: plan.cropX,
          y: plan.cropY,
          width: plan.cropW,
          height: plan.cropH,
        );
      }
    }

    if (work.width != target.width || work.height != target.height) {
      final resample = defaultResample(
        math.max(work.width, work.height),
        math.max(target.width, target.height),
      );
      work = img.copyResize(
        work,
        width: target.width,
        height: target.height,
        interpolation: switch (resample) {
          Resample.high => img.Interpolation.cubic,
          Resample.balanced => img.Interpolation.average,
          Resample.fast => img.Interpolation.linear,
        },
      );
    }

    tick(0.45);

    work = _applyAdjustments(work, s);
    work = _applyFilters(work, s);

    tick(0.62);

    if (spec.mode == ResizeMode.exactFit) {
      work = _pad(work, outer, toCodecColor(s.padColor));
    }

    if (s.watermark.active) {
      work = _applyWatermark(work, s.watermark);
    }

    tick(0.72);

    work = _prepareChannels(work, outFormat);

    if (s.stripMetadata) {
      work.exif = img.ExifData();
    }

    tick(0.80);

    final budget = s.targetKb == null ? null : s.targetKb! * 1024;
    if (budget != null && outFormat.supportsQuality) {
      final solved = _solveToBudget(work, outFormat, s, budget);
      tick(1.0);
      return solved;
    }

    final encoded = _encode(work, outFormat, s);
    tick(1.0);

    return EngineResult(
      bytes: encoded,
      width: work.width,
      height: work.height,
      extension: outFormat.extension!,
      quality: outFormat.supportsQuality ? s.quality : null,
    );
  }

  // ------------------------------------------------------------------ output
  static OutputFormat _resolveFormat(
    OutputFormat chosen,
    bool keepExtension,
    String? sourceExt,
  ) {
    if (chosen != OutputFormat.keep) return chosen;
    if (keepExtension) {
      final mapped = OutputFormat.fromExtension(sourceExt);
      if (mapped != OutputFormat.keep) return mapped;
    }
    return OutputFormat.jpeg;
  }

  static img.Image _applyAdjustments(img.Image src, ResizeSettings s) {
    final a = s.adjustments;
    if (a.isNeutral) return src;

    var out = img.adjustColor(
      src,
      brightness: a.brightness == 0 ? null : a.brightness,
      contrast: a.contrast == 0 ? null : a.contrast,
      saturation: a.saturation == 0 ? null : a.saturation,
      exposure: a.exposure == 0 ? null : a.exposure,
      hue: a.hue == 0 ? null : a.hue,
      gamma: a.gamma == 0 ? null : a.gamma,
      amount: a.amount,
    );

    // A flat histogram stretch recovers blown or muddy shots. Only fires when
    // the caller has not set brightness/contrast/exposure/gamma, so intent wins.
    if (a.brightness == 0 &&
        a.contrast == 0 &&
        a.exposure == 0 &&
        a.gamma == 0) {
      out = img.normalize(out, min: 0, max: 255);
    }

    return out;
  }

  static img.Image _applyFilters(img.Image src, ResizeSettings s) {
    var out = src;

    if (s.blurRadius >= 0.5) {
      out = img.gaussianBlur(out, radius: s.blurRadius.round());
    }
    if (s.sharpenAmount > 0) {
      out = img.convolution(
        out,
        filter: _sharpenKernel,
        amount: s.sharpenAmount,
      );
    }
    if (s.grayscale > 0) {
      out = _mix(out, img.grayscale(out), s.grayscale);
    }
    if (s.sepia > 0) {
      out = _mix(out, img.sepia(out), s.sepia);
    }

    return out;
  }

  static img.Image _mix(img.Image a, img.Image b, num t) {
    if (t >= 1) return b;
    if (t <= 0) return a;
    final out = a.clone();
    for (final p in out) {
      final q = b.getPixel(p.x, p.y);
      p
        ..r = _lerp(p.r, q.r, t)
        ..g = _lerp(p.g, q.g, t)
        ..b = _lerp(p.b, q.b, t)
        ..a = _lerp(p.a, q.a, t);
    }
    return out;
  }

  static int _lerp(num a, num b, num t) =>
      (a + (b - a) * t).round().clamp(0, 255);

  static img.Image _pad(img.Image src, TargetSize target, img.Color color) {
    if (src.width == target.width && src.height == target.height) return src;
    final out = img.Image(
      width: target.width,
      height: target.height,
      numChannels: 4,
    );
    img.fill(out, color: color);
    img.compositeImage(
      out,
      src,
      dstX: (target.width - src.width) ~/ 2,
      dstY: (target.height - src.height) ~/ 2,
      blend: img.BlendMode.alpha,
    );
    return out;
  }

  // -------------------------------------------------------------- watermark
  static img.BitmapFont _fontForHeight(int h) {
    if (h <= 16) return img.arial14;
    if (h <= 28) return img.arial24;
    return img.arial48;
  }

  static img.Image _applyWatermark(img.Image src, WatermarkSettings wm) {
    final text = wm.text.trim();
    if (text.isEmpty) return src;

    final base = math.min(src.width, src.height);
    final targetHeight = (base * wm.scale).round().clamp(8, 220);
    final color = toCodecColor(wm.color);

    // Render onto a deliberately oversized canvas, then crop to the ink box and
    // scale that down. Drawing straight into a tightly-sized layer clips glyphs.
    final canvas = img.Image(
      width: math.min(src.width * 2, 4096),
      height: math.min(targetHeight * 3, 1024),
      numChannels: 4,
    );
    img.drawString(
      canvas,
      text,
      font: _fontForHeight(targetHeight),
      x: 0,
      y: 0,
      color: color,
    );

    final bbox = _tightBounds(canvas);
    if (bbox == null) return src;

    var layer = img.copyCrop(
      canvas,
      x: bbox.x,
      y: bbox.y,
      width: bbox.width,
      height: bbox.height,
    );
    layer = img.copyResize(
      layer,
      width: (bbox.width * (targetHeight / bbox.height)).round().clamp(
        1,
        src.width,
      ),
      height: targetHeight.clamp(1, src.height),
      interpolation: img.Interpolation.average,
    );
    layer = _applyOpacity(layer, wm.opacity);

    final w = layer.width;
    final h = layer.height;
    final margin = (base * wm.margin).round();
    late final int dx;
    late final int dy;
    switch (wm.corner) {
      case WatermarkCorner.topLeft:
        dx = margin;
        dy = margin;
      case WatermarkCorner.topRight:
        dx = src.width - w - margin;
        dy = margin;
      case WatermarkCorner.bottomLeft:
        dx = margin;
        dy = src.height - h - margin;
      case WatermarkCorner.bottomRight:
        dx = src.width - w - margin;
        dy = src.height - h - margin;
      case WatermarkCorner.center:
        dx = (src.width - w) ~/ 2;
        dy = (src.height - h) ~/ 2;
    }

    final out = src.clone();
    img.compositeImage(
      out,
      layer,
      dstX: dx.clamp(0, math.max(0, src.width - 1)),
      dstY: dy.clamp(0, math.max(0, src.height - 1)),
      blend: img.BlendMode.alpha,
    );
    return out;
  }

  static ({int x, int y, int width, int height})? _tightBounds(img.Image im) {
    var minX = im.width;
    var minY = im.height;
    var maxX = -1;
    var maxY = -1;
    for (final p in im) {
      if (p.a != 0) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }
    if (maxX < 0 || maxY < 0) return null;
    return (x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
  }

  static img.Image _applyOpacity(img.Image src, double opacity) {
    if (opacity >= 1) return src;
    final out = src.clone();
    for (final p in out) {
      p.a = opacity <= 0 ? 0 : (p.a * opacity).round().clamp(0, 255);
    }
    return out;
  }

  /// Flattens alpha where the container cannot carry it.
  static img.Image _prepareChannels(img.Image src, OutputFormat fmt) {
    switch (fmt) {
      case OutputFormat.jpeg:
      case OutputFormat.bmp:
        return src.hasAlpha ? src.convert(numChannels: 3) : src;
      case OutputFormat.gif:
        return src.hasAlpha ? src : src.convert(numChannels: 4);
      case OutputFormat.png:
      case OutputFormat.webp:
      case OutputFormat.tiff:
        return src.hasAlpha ? src : src.convert(numChannels: 4);
      case OutputFormat.keep:
        return src;
    }
  }

  // ---------------------------------------------------------------- encoding
  static Uint8List _encode(
    img.Image im,
    OutputFormat fmt,
    ResizeSettings s, {
    int? quality,
  }) {
    final q = quality ?? s.quality;
    switch (fmt) {
      case OutputFormat.jpeg:
        return img.encodeJpg(
          im,
          quality: q,
          chroma: s.chroma == ChromaMode.yuv420
              ? img.JpegChroma.yuv420
              : img.JpegChroma.yuv444,
        );
      case OutputFormat.png:
        return img.encodePng(im, level: s.pngLevel);
      case OutputFormat.webp:
        return img.encodeWebP(
          im,
          lossless: s.webpLossless,
          quality: s.webpLossless ? 100 : q,
          method: s.webpMethod,
        );
      case OutputFormat.gif:
        return img.encodeGif(im, singleFrame: true);
      case OutputFormat.tiff:
        return img.encodeTiff(im, singleFrame: true);
      case OutputFormat.bmp:
        return img.encodeBmp(im);
      case OutputFormat.keep:
        throw EngineError('Unresolved output format.');
    }
  }

  /// Binary-searches the best quality whose encoded size fits [budgetBytes].
  static EngineResult _solveToBudget(
    img.Image im,
    OutputFormat fmt,
    ResizeSettings s,
    int budgetBytes,
  ) {
    final minQ = fmt == OutputFormat.jpeg ? 25 : 10;
    final maxQ = fmt == OutputFormat.jpeg ? 96 : 92;

    final atMax = _encode(im, fmt, s, quality: maxQ);
    if (atMax.length <= budgetBytes) {
      return EngineResult(
        bytes: atMax,
        width: im.width,
        height: im.height,
        extension: fmt.extension!,
        quality: maxQ,
      );
    }

    final atMin = _encode(im, fmt, s, quality: minQ);
    if (atMin.length > budgetBytes) {
      return EngineResult(
        bytes: atMin,
        width: im.width,
        height: im.height,
        extension: fmt.extension!,
        quality: minQ,
        metTarget: false,
      );
    }

    var lo = minQ;
    var hi = maxQ;
    var bestQ = minQ;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final size = _encode(im, fmt, s, quality: mid).length;
      if (size <= budgetBytes) {
        bestQ = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    return EngineResult(
      bytes: _encode(im, fmt, s, quality: bestQ),
      width: im.width,
      height: im.height,
      extension: fmt.extension!,
      quality: bestQ,
    );
  }

  // ----------------------------------------------------------------- preview
  /// Small PNG for the UI preview pane.
  static Uint8List? thumbnail(Uint8List source, {int maxDim = 720}) {
    final decoded = img.decodeImage(source);
    if (decoded == null || !decoded.isValid) return null;
    var work = decoded;
    if (work.exif.imageIfd.hasOrientation &&
        work.exif.imageIfd.orientation != 1) {
      work = img.bakeOrientation(work);
    }
    final longest = math.max(work.width, work.height);
    if (longest > maxDim) {
      final k = maxDim / longest;
      work = img.copyResize(
        work,
        width: (work.width * k).round(),
        height: (work.height * k).round(),
        interpolation: img.Interpolation.average,
      );
    }
    return img.encodePng(work, level: 3);
  }
}

/// Runs one job through the engine and updates its state.
Future<void> processJob(ImageJob job, ResizeSettings settings) async {
  job.markRunning(0.0);
  try {
    final res = await ResizeEngine.run(
      job.bytes,
      settings,
      name: job.name,
      onProgress: job.markRunning,
    );
    job.markDone(
      output: res.bytes,
      width: res.width,
      height: res.height,
      quality: res.quality,
    );
  } on EngineError catch (e) {
    job.markFailed(e.message);
  } catch (e) {
    job.markFailed('Unexpected error: $e');
  }
}

/// Renders `{token}` patterns for an output filename.
String renderTemplate(
  String template, {
  required String baseName,
  required int outWidth,
  required int outHeight,
  required int srcWidth,
  required int srcHeight,
  required String extension,
  required int index,
  String? presetName,
}) {
  var s = template;
  s = s.replaceAll('{name}', baseName);
  s = s.replaceAll('{w}', outWidth.toString());
  s = s.replaceAll('{h}', outHeight.toString());
  s = s.replaceAll('{origw}', srcWidth.toString());
  s = s.replaceAll('{origh}', srcHeight.toString());
  s = s.replaceAll('{index}', index.toString().padLeft(4, '0'));
  s = s.replaceAll('{ext}', extension);
  s = s.replaceAll('{preset}', presetName ?? 'custom');
  s = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) s = baseName;
  return s;
}
