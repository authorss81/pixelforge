import 'resize_mode.dart';

/// A named, ready-made output configuration.
class ResizePreset {
  const ResizePreset({
    required this.name,
    required this.group,
    required this.mode,
    this.width,
    this.height,
    this.format,
    this.quality,
    this.targetKb,
    this.note = '',
  });

  final String name;
  final String group;
  final ResizeMode mode;
  final int? width;
  final int? height;

  /// Output container extension, or null to keep the source format.
  final String? format;
  final int? quality;

  /// If set, quality is auto-solved to land under this size.
  final int? targetKb;
  final String note;
}

class PresetGroup {
  const PresetGroup(this.name, this.presets);

  final String name;
  final List<ResizePreset> presets;
}

class Presets {
  const Presets._();

  static const social = <ResizePreset>[
    ResizePreset(
      name: 'Instagram Post',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 1080,
      height: 1080,
      format: 'jpg',
      quality: 88,
    ),
    ResizePreset(
      name: 'Instagram Story',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 1080,
      height: 1920,
      format: 'jpg',
      quality: 88,
    ),
    ResizePreset(
      name: 'Facebook Post',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 1200,
      height: 630,
      format: 'jpg',
      quality: 86,
    ),
    ResizePreset(
      name: 'X / Twitter Post',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 1600,
      height: 900,
      format: 'jpg',
      quality: 86,
    ),
    ResizePreset(
      name: 'YouTube Thumbnail',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 1280,
      height: 720,
      format: 'jpg',
      quality: 88,
      note: 'Under 2 MB',
    ),
    ResizePreset(
      name: 'YouTube Banner',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 2560,
      height: 1440,
      format: 'jpg',
      quality: 90,
    ),
    ResizePreset(
      name: 'LinkedIn Post',
      group: 'Social',
      mode: ResizeMode.longestSide,
      width: 1200,
      height: 1200,
      format: 'jpg',
      quality: 86,
    ),
    ResizePreset(
      name: 'LinkedIn Banner',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 1584,
      height: 396,
      format: 'jpg',
      quality: 90,
    ),
    ResizePreset(
      name: 'Pinterest Pin',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 1000,
      height: 1500,
      format: 'jpg',
      quality: 88,
    ),
    ResizePreset(
      name: 'TikTok Video',
      group: 'Social',
      mode: ResizeMode.exactCrop,
      width: 1080,
      height: 1920,
      format: 'jpg',
      quality: 88,
    ),
    ResizePreset(
      name: 'App Icon',
      group: 'Social',
      mode: ResizeMode.exactStretch,
      width: 1024,
      height: 1024,
      format: 'png',
    ),
  ];

  static const web = <ResizePreset>[
    ResizePreset(
      name: 'Web / Hero',
      group: 'Web',
      mode: ResizeMode.exactCrop,
      width: 1920,
      height: 1080,
      format: 'webp',
      quality: 80,
    ),
    ResizePreset(
      name: 'Web / Retina 2x',
      group: 'Web',
      mode: ResizeMode.width,
      width: 1600,
      format: 'webp',
      quality: 82,
    ),
    ResizePreset(
      name: 'Web / Card',
      group: 'Web',
      mode: ResizeMode.exactCrop,
      width: 800,
      height: 418,
      format: 'webp',
      quality: 80,
    ),
    ResizePreset(
      name: 'Web / Thumbnail',
      group: 'Web',
      mode: ResizeMode.exactCrop,
      width: 400,
      height: 400,
      format: 'webp',
      quality: 75,
    ),
    ResizePreset(
      name: 'Web / Favicon',
      group: 'Web',
      mode: ResizeMode.exactStretch,
      width: 512,
      height: 512,
      format: 'png',
    ),
  ];

  static const docs = <ResizePreset>[
    ResizePreset(
      name: 'Passport / ID Photo',
      group: 'Documents',
      mode: ResizeMode.exactCrop,
      width: 413,
      height: 531,
      format: 'jpg',
      quality: 92,
      note: '35x45mm at 300dpi',
    ),
    ResizePreset(
      name: 'Resume Photo',
      group: 'Documents',
      mode: ResizeMode.exactCrop,
      width: 413,
      height: 531,
      format: 'jpg',
      quality: 92,
      note: '1x1 inch at 300dpi',
    ),
    ResizePreset(
      name: 'Visa / Form Upload 50 KB',
      group: 'Documents',
      mode: ResizeMode.exactCrop,
      width: 700,
      height: 700,
      format: 'jpg',
      targetKb: 50,
    ),
    ResizePreset(
      name: 'Exam Upload 100 KB',
      group: 'Documents',
      mode: ResizeMode.exactCrop,
      width: 800,
      height: 800,
      format: 'jpg',
      targetKb: 100,
    ),
    ResizePreset(
      name: 'Print A4 @ 300dpi',
      group: 'Documents',
      mode: ResizeMode.exactFit,
      width: 2480,
      height: 3508,
      format: 'jpg',
      quality: 90,
      note: 'Pads with white',
    ),
    ResizePreset(
      name: 'Print 4x6in @ 300dpi',
      group: 'Documents',
      mode: ResizeMode.exactFit,
      width: 1200,
      height: 1800,
      format: 'jpg',
      quality: 90,
    ),
  ];

  static const optimize = <ResizePreset>[
    ResizePreset(
      name: 'Max Compress Web',
      group: 'Optimize',
      mode: ResizeMode.longestSide,
      width: 1920,
      height: 1920,
      format: 'webp',
      quality: 72,
    ),
    ResizePreset(
      name: 'Tiny 20 KB',
      group: 'Optimize',
      mode: ResizeMode.exactCrop,
      width: 400,
      height: 400,
      format: 'jpg',
      targetKb: 20,
    ),
    ResizePreset(
      name: 'Email Attachment',
      group: 'Optimize',
      mode: ResizeMode.longestSide,
      width: 1024,
      height: 1024,
      format: 'jpg',
      quality: 75,
    ),
    ResizePreset(
      name: 'Lossless PNG',
      group: 'Optimize',
      mode: ResizeMode.original,
      format: 'png',
    ),
  ];

  static const all = <ResizePreset>[...social, ...web, ...docs, ...optimize];

  static List<PresetGroup> get groups => const [
    PresetGroup('Social', social),
    PresetGroup('Web', web),
    PresetGroup('Documents', docs),
    PresetGroup('Optimize', optimize),
  ];

  static ResizePreset? byName(String name) {
    for (final p in all) {
      if (p.name == name) return p;
    }
    return null;
  }
}
