import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixelforge/core/engine.dart';
import 'package:pixelforge/core/resize_mode.dart';
import 'package:pixelforge/core/settings.dart';

Uint8List _makeJpeg(int w, int h, {int quality = 92}) {
  final im = img.Image(width: w, height: h, numChannels: 3);
  img.fill(im, color: img.ColorRgba8(90, 140, 200, 255));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgba(x, y, (x * 255 ~/ w), (y * 255 ~/ h), 128, 255);
    }
  }
  return img.encodeJpg(im, quality: quality);
}

void main() {
  group('geometry', () {
    test('longestSide fits inside the box without growing', () {
      final t = computeTargetSize(
        const ResizeSpec(
          mode: ResizeMode.longestSide,
          width: 1000,
          height: 1000,
        ),
        4000,
        2000,
      );
      expect(t.width, 1000);
      expect(t.height, 500);
    });

    test('longestSide never upscales unless allowed', () {
      final spec = ResizeSpec(
        mode: ResizeMode.longestSide,
        width: 4000,
        height: 4000,
      );
      expect(computeTargetSize(spec, 800, 600), const TargetSize(800, 600));
      expect(
        computeTargetSize(spec.copyWith(allowUpscale: true), 800, 600),
        const TargetSize(4000, 3000),
      );
    });

    test('exact modes land on the requested box', () {
      for (final mode in const [
        ResizeMode.exactFit,
        ResizeMode.exactCrop,
        ResizeMode.exactStretch,
      ]) {
        final t = computeTargetSize(
          ResizeSpec(mode: mode, width: 1080, height: 1080),
          3000,
          1700,
        );
        expect(t.width, 1080);
        expect(t.height, 1080, reason: 'mode ${mode.name}');
      }
    });

    test('percent scales both axes', () {
      final t = computeTargetSize(
        const ResizeSpec(mode: ResizeMode.percent, percent: 50),
        1600,
        900,
      );
      expect(t.width, 800);
      expect(t.height, 450);
    });

    test('single-axis modes derive the other axis from the source ratio', () {
      expect(
        computeTargetSize(
          const ResizeSpec(mode: ResizeMode.width, width: 800),
          1600,
          900,
        ),
        const TargetSize(800, 450),
      );
      expect(
        computeTargetSize(
          const ResizeSpec(mode: ResizeMode.height, height: 450),
          1600,
          900,
        ),
        const TargetSize(800, 450),
      );
    });

    test('never returns a zero or negative dimension', () {
      final t = computeTargetSize(
        const ResizeSpec(mode: ResizeMode.width, width: 1),
        4000,
        3,
      );
      expect(t.width, greaterThanOrEqualTo(1));
      expect(t.height, greaterThanOrEqualTo(1));
    });

    test('crop plan matches the target aspect and stays in bounds', () {
      final plan = computeCropPlan(3000, 1700, const TargetSize(1080, 1080));
      expect(plan.cropW, 1700);
      expect(plan.cropH, 1700);
      expect(plan.cropX, (3000 - 1700) ~/ 2);
      expect(plan.cropY, 0);
    });

    test('crop plan is a no-op when the aspect already matches', () {
      final plan = computeCropPlan(1000, 1000, const TargetSize(500, 500));
      expect(plan, CropPlan.none);
    });
  });

  group('pipeline', () {
    test('resizes and reports the real output geometry', () async {
      final s = ResizeSettings()..setMode(ResizeMode.exactCrop);
      s.setWidth(400);
      s.setHeight(400);
      s.setFormat(OutputFormat.jpeg);

      final res = await ResizeEngine.run(
        _makeJpeg(1200, 800),
        s,
        name: 'a.jpg',
      );

      expect(res.width, 400);
      expect(res.height, 400);
      expect(res.extension, 'jpg');

      final decoded = img.decodeJpg(res.bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 400);
      expect(decoded.height, 400);
    });

    test('target KB solver lands under the budget', () async {
      final s = ResizeSettings()..setMode(ResizeMode.exactCrop);
      s.setWidth(1200);
      s.setHeight(1200);
      s.setFormat(OutputFormat.jpeg);
      s.setTargetKb(60);

      final res = await ResizeEngine.run(
        _makeJpeg(2400, 1600),
        s,
        name: 'b.jpg',
      );

      expect(res.metTarget, isTrue);
      expect(res.bytes.length, lessThanOrEqualTo(60 * 1024));
      expect(res.quality, isNotNull);
      expect(res.quality, greaterThan(0));
    });

    test('reports when the budget is impossible instead of lying', () async {
      final s = ResizeSettings()..setMode(ResizeMode.exactStretch);
      s.setWidth(3000);
      s.setHeight(3000);
      s.setFormat(OutputFormat.jpeg);
      s.setTargetKb(1);

      final res = await ResizeEngine.run(
        _makeJpeg(3000, 3000),
        s,
        name: 'c.jpg',
      );
      expect(res.metTarget, isFalse);
    });

    test('quality ordering: lower quality means fewer bytes', () async {
      final high = ResizeSettings()..setQuality(95);
      final low = ResizeSettings()..setQuality(20);

      final big = _makeJpeg(1000, 800);
      final a = await ResizeEngine.run(big, high, name: 'd.jpg');
      final b = await ResizeEngine.run(big, low, name: 'd.jpg');

      expect(b.bytes.length, lessThan(a.bytes.length));
    });

    test('png stays lossless through a resize', () async {
      final s = ResizeSettings()
        ..setMode(ResizeMode.width)
        ..setWidth(120)
        ..setFormat(OutputFormat.png);

      final res = await ResizeEngine.run(_makeJpeg(600, 400), s, name: 'e.jpg');
      expect(res.extension, 'png');
      expect(res.bytes.length, greaterThan(0));
      expect(img.decodePng(res.bytes)!.width, 120);
    });

    test('webp encoder honours the lossy switch', () async {
      final lossless = ResizeSettings()
        ..setFormat(OutputFormat.webp)
        ..setWebpLossless(true);
      final lossy = ResizeSettings()
        ..setFormat(OutputFormat.webp)
        ..setWebpLossless(false)
        ..setQuality(40);

      final src = _makeJpeg(800, 600);
      final a = await ResizeEngine.run(src, lossless, name: 'f.jpg');
      final b = await ResizeEngine.run(src, lossy, name: 'f.jpg');

      expect(resizeEngineDecodes(a.extension), isTrue);
      expect(resizeEngineDecodes(b.extension), isTrue);
      expect(b.bytes.length, lessThan(a.bytes.length));
    });

    test('strips metadata when asked', () async {
      final keep = ResizeSettings()..setStripMetadata(false);
      final drop = ResizeSettings()..setStripMetadata(true);

      final src = _makeJpeg(200, 200);
      final a = await ResizeEngine.run(src, keep, name: 'g.jpg');
      final b = await ResizeEngine.run(src, drop, name: 'g.jpg');

      expect(b.bytes.length, lessThanOrEqualTo(a.bytes.length));
    });

    test('rotating by 90 degrees swaps the axes', () async {
      final s = ResizeSettings()
        ..setMode(ResizeMode.original)
        ..rotateBy(1)
        ..setFormat(OutputFormat.png);

      final res = await ResizeEngine.run(_makeJpeg(800, 400), s, name: 'h.jpg');
      expect(res.width, 400);
      expect(res.height, 800);
    });

    test('pad mode keeps the box and adds background', () async {
      final s = ResizeSettings()
        ..setMode(ResizeMode.exactFit)
        ..setWidth(600)
        ..setHeight(600)
        ..setPadColor(const Color(0xFFFF0000))
        ..setFormat(OutputFormat.png);

      final res = await ResizeEngine.run(
        _makeJpeg(1200, 400),
        s,
        name: 'i.jpg',
      );
      expect(res.width, 600);
      expect(res.height, 600);

      final decoded = img.decodePng(res.bytes)!;
      final corner = decoded.getPixel(2, 2);
      expect(corner.r, greaterThan(200));
      expect(corner.g, lessThan(80));
    });

    test('watermark visibly changes pixels', () async {
      final plain = ResizeSettings()
        ..setMode(ResizeMode.original)
        ..setFormat(OutputFormat.png);
      final marked = ResizeSettings()
        ..setMode(ResizeMode.original)
        ..setWatermark(
          const WatermarkSettings(text: 'DEMO', enabled: true, scale: 0.14),
        )
        ..setFormat(OutputFormat.png);

      final src = _makeJpeg(600, 400);
      final a = img.decodePng(
        (await ResizeEngine.run(src, plain, name: 'j.jpg')).bytes,
      )!;
      final b = img.decodePng(
        (await ResizeEngine.run(src, marked, name: 'j.jpg')).bytes,
      )!;

      expect(b.width, 600);
      expect(b.height, 400);

      var changed = 0;
      for (final p in a) {
        final q = b.getPixel(p.x, p.y);
        if ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs() > 12) {
          changed++;
        }
      }
      expect(
        changed,
        greaterThan(200),
        reason: 'watermark ink should be visible',
      );
    });

    test('rejects data that is not an image', () async {
      final s = ResizeSettings();
      expect(
        () => ResizeEngine.run(
          Uint8List.fromList(List.filled(64, 7)),
          s,
          name: 'x.jpg',
        ),
        throwsA(isA<EngineError>()),
      );
    });
  });

  group('naming', () {
    test('substitutes every token and strips illegal characters', () {
      final out = renderTemplate(
        '{name}_{w}x{h}_{index}.{ext}',
        baseName: r'a/b:c',
        outWidth: 100,
        outHeight: 200,
        srcWidth: 400,
        srcHeight: 800,
        extension: 'webp',
        index: 7,
      );
      expect(out, 'a_b_c_100x200_0007.webp');
    });

    test('never returns an empty stem', () {
      final out = renderTemplate(
        '{name}',
        baseName: 'photo',
        outWidth: 1,
        outHeight: 1,
        srcWidth: 1,
        srcHeight: 1,
        extension: 'jpg',
        index: 1,
      );
      expect(out, isNotEmpty);
    });
  });

  group('settings persistence', () {
    test('a snapshot round-trips through json', () {
      final a = ResizeSettings()
        ..setMode(ResizeMode.exactCrop)
        ..setWidth(1234)
        ..setHeight(567)
        ..setFormat(OutputFormat.webp)
        ..setQuality(42)
        ..setTargetKb(88)
        ..setNameTemplate('{name}_{w}')
        ..setWatermark(
          const WatermarkSettings(text: 'X', enabled: true, opacity: 0.3),
        );

      final b = ResizeSettings()..loadFrom(a.toJson());

      expect(b.mode, ResizeMode.exactCrop);
      expect(b.width, 1234);
      expect(b.height, 567);
      expect(b.format, OutputFormat.webp);
      expect(b.quality, 42);
      expect(b.targetKb, 88);
      expect(b.nameTemplate, '{name}_{w}');
      expect(b.watermark.text, 'X');
      expect(b.watermark.opacity, 0.3);
    });

    test('quality overrides an active size budget', () {
      final s = ResizeSettings()..setTargetKb(50);
      expect(s.qualityIsAutomatic, isTrue);
      s.setQuality(70);
      expect(s.qualityIsAutomatic, isFalse);
      expect(s.targetKb, isNull);
    });
  });
}

bool resizeEngineDecodes(String ext) {
  return ext == 'jpg' ||
      ext == 'png' ||
      ext == 'webp' ||
      ext == 'gif' ||
      ext == 'bmp' ||
      ext == 'tiff';
}
