import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixelforge/core/engine.dart';
import 'package:pixelforge/core/resize_mode.dart';
import 'package:pixelforge/core/settings.dart';

Uint8List makeAnimatedGif(int w, int h, int frames) {
  final out = img.Image(width: w, height: h, numChannels: 3);
  img.fill(out, color: img.ColorRgba8(0, 0, 255, 255));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      out.setPixelRgba(x, y, (x * 255 ~/ w), (y * 255 ~/ h), 200, 255);
    }
  }
  out.frameDuration = 120;
  for (var f = 1; f < frames; f++) {
    final nf = out.addFrame(img.Image(width: w, height: h, numChannels: 3));
    nf.frameDuration = 120;
    img.fill(nf, color: img.ColorRgba8(f * 40, 20, 10, 255));
    nf.setPixelRgba(0, 0, 255, 0, 0, 255);
  }
  return img.encodeGif(out, singleFrame: false);
}

void main() {
  test('probe engine today', () async {
    final bytes = makeAnimatedGif(60, 40, 4);
    final s = ResizeSettings()
      ..setMode(ResizeMode.width)
      ..setWidth(30)
      ..setFormat(OutputFormat.gif);
    final res = await ResizeEngine.run(bytes, s, name: 'a.gif');
    // ignore: avoid_print
    print('out ${res.width}x${res.height} bytes=${res.bytes.length}');
    final d = img.decodeGif(res.bytes)!;
    // ignore: avoid_print
    print('frames=${d.numFrames} ${d.width}x${d.height} '
        'ch=${d.numChannels} pal=${d.hasPalette}');
    // ignore: avoid_print
    print('p00=${d.getPixel(0, 0).r},${d.getPixel(0, 0).g},'
        '${d.getPixel(0, 0).b} p10=${d.getPixel(10, 0).r},'
        '${d.getPixel(10, 0).g},${d.getPixel(10, 0).b}');

    // still gif
    final still = img.encodeGif(
      img.decodeGif(bytes)!,
      singleFrame: true,
    );
    final r2 = await ResizeEngine.run(still, s, name: 'b.gif');
    final d2 = img.decodeGif(r2.bytes)!;
    // ignore: avoid_print
    print('still frames=${d2.numFrames} ${d2.width}x${d2.height} '
        'p00=${d2.getPixel(0, 0).r},${d2.getPixel(0, 0).g},'
        '${d2.getPixel(0, 0).b}');
  });
}