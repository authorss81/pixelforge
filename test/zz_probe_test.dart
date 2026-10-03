import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List makeAnimatedGif(int w, int h, int frames) {
  final im = img.Image(width: w, height: h, numChannels: 3);
  img.fill(im, color: img.ColorRgba8(0, 0, 255, 255));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgba(x, y, (x * 255 ~/ w), (y * 255 ~/ h), 200, 255);
    }
  }
  final out = img.Image(width: w, height: h, numChannels: 3);
  out.frameDuration = 120;
  for (var f = 1; f < frames; f++) {
    final nf = out.addFrame(
      img.Image(width: w, height: h, numChannels: 3),
    );
    nf.frameDuration = 120;
    img.fill(nf, color: img.ColorRgba8(f * 40, 20, 10, 255));
    nf.setPixelRgba(0, 0, 255, 0, 0, 255);
  }
  return img.encodeGif(out, singleFrame: false);
}

void main() {
  test('probe', () {
    final bytes = makeAnimatedGif(60, 40, 4);
    final d = img.decodeNamedImage('a.gif', bytes)!;
    // ignore: avoid_print
    print('decoded frames=${d.numFrames} w=${d.width} h=${d.height} '
        'ch=${d.numChannels} palette=${d.hasPalette} hasAlpha=${d.hasAlpha} '
        'loop=${d.loopCount} dur0=${d.frames[0].frameDuration}');
    for (final f in d.frames) {
      // ignore: avoid_print
      print('  frame ${f.frameIndex} ${f.width}x${f.height} '
          'ch=${f.numChannels} pal=${f.hasPalette} dur=${f.frameDuration}');
    }

    final single = img.encodeGif(d, singleFrame: true);
    final anim = img.encodeGif(d, singleFrame: false);
    // ignore: avoid_print
    print('single=${single.length} anim=${anim.length}');
    final dAnim = img.decodeGif(anim)!;
    // ignore: avoid_print
    print('anim roundtrip frames=${dAnim.numFrames} '
        'durs=${dAnim.frames.map((f) => f.frameDuration).toList()}');

    // palette resize with average interpolation
    final pal = d.frames[0];
    // ignore: avoid_print
    print('palette frame: numChannels=${pal.numChannels} '
        'hasPalette=${pal.hasPalette}');
    try {
      final r = img.copyResize(
        pal,
        width: 30,
        height: 20,
        interpolation: img.Interpolation.average,
      );
      // ignore: avoid_print
      print('average resize on palette OK: ${r.width}x${r.height} '
          'ch=${r.numChannels} p00=${r.getPixel(0, 0).r},'
          '${r.getPixel(0, 0).g},${r.getPixel(0, 0).b}');
      final rr = img.decodeImage(img.encodePng(r.convert(numChannels: 4)));
      // ignore: avoid_print
      print('as png ${rr?.width}x${rr?.height}');
    } catch (e) {
      // ignore: avoid_print
      print('average resize on palette FAILED: $e');
    }

    // convert 1-channel palette to 4 channels
    final conv = pal.convert(numChannels: 4);
    // ignore: avoid_print
    print('converted: ch=${conv.numChannels} pal=${conv.hasPalette} '
        'p00=${conv.getPixel(0, 0).r},${conv.getPixel(0, 0).g},'
        '${conv.getPixel(0, 0).b},${conv.getPixel(0, 0).a}');

    // webp animation roundtrip
    final w = img.Image(width: 60, height: 40, numChannels: 3);
    img.fill(w, color: img.ColorRgba8(10, 200, 30, 255));
    w.frameDuration = 120;
    for (var f = 1; f < 3; f++) {
      final nf = w.addFrame(img.Image(width: 60, height: 40, numChannels: 3));
      nf.frameDuration = 80;
      img.fill(nf, color: img.ColorRgba8(f * 60, 10, 90, 255));
    }
    final wb = img.encodeWebP(w, singleFrame: false, lossless: false, quality: 80);
    final wd = img.decodeWebP(wb)!;
    // ignore: avoid_print
    print('webp frames=${wd.numFrames} durs='
        '${wd.frames.map((f) => f.frameDuration).toList()}');
    for (final f in wd.frames) {
      // ignore: avoid_print
      print('  wframe ${f.width}x${f.height} ch=${f.numChannels} '
          'pal=${f.hasPalette} dur=${f.frameDuration}');
    }
  });
}