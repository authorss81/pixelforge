import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presets.dart';
import 'resize_mode.dart';

/// Output container/codec.
enum OutputFormat {
  keep('Keep source', null),
  jpeg('JPEG', 'jpg'),
  png('PNG', 'png'),
  webp('WebP', 'webp'),
  gif('GIF', 'gif'),
  tiff('TIFF', 'tiff'),
  bmp('BMP', 'bmp');

  const OutputFormat(this.label, this.extension);

  final String label;
  final String? extension;

  bool get supportsAlpha => this != jpeg && this != bmp;

  /// True when a quality slider is meaningful.
  bool get supportsQuality => this == jpeg || this == webp;

  /// True when the container can carry more than one frame. Only these two
  /// keep an animation; everything else is flattened and the caller is told.
  bool get supportsFrames => this == gif || this == webp;

  static OutputFormat fromExtension(String? ext) {
    if (ext == null) return OutputFormat.keep;
    final e = ext.toLowerCase().replaceAll('.', '');
    for (final f in OutputFormat.values) {
      if (f.extension == e) return f;
    }
    if (e == 'jpeg') return OutputFormat.jpeg;
    if (e == 'tif') return OutputFormat.tiff;
    return OutputFormat.keep;
  }
}

/// Which channel quality tuning is applied to.
enum ChromaMode {
  yuv444('4:4:4 - best quality', '444'),
  yuv420('4:2:0 - smaller', '420');

  const ChromaMode(this.label, this.value);

  final String label;
  final String value;
}

/// A single tone / colour adjustment, all zero-based meaning "no change".
class Adjustments {
  const Adjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.exposure = 0,
    this.hue = 0,
    this.gamma = 0,
    this.amount = 1,
  });

  final num brightness;
  final num contrast;
  final num saturation;
  final num exposure;
  final num hue;
  final num gamma;
  final num amount;

  bool get isNeutral =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      exposure == 0 &&
      hue == 0 &&
      gamma == 0;

  Adjustments copyWith({
    num? brightness,
    num? contrast,
    num? saturation,
    num? exposure,
    num? hue,
    num? gamma,
    num? amount,
  }) => Adjustments(
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    exposure: exposure ?? this.exposure,
    hue: hue ?? this.hue,
    gamma: gamma ?? this.gamma,
    amount: amount ?? this.amount,
  );

  Map<String, dynamic> toJson() => {
    'b': brightness.toString(),
    'c': contrast.toString(),
    's': saturation.toString(),
    'e': exposure.toString(),
    'h': hue.toString(),
    'g': gamma.toString(),
    'a': amount.toString(),
  };

  static Adjustments fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Adjustments();
    num n(String k) {
      final v = j[k];
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? 0;
      return 0;
    }

    return Adjustments(
      brightness: n('b'),
      contrast: n('c'),
      saturation: n('s'),
      exposure: n('e'),
      hue: n('h'),
      gamma: n('g'),
      amount: j['a'] == null ? 1 : n('a'),
    );
  }
}

/// Where a watermark sits relative to the canvas.
enum WatermarkCorner { topLeft, topRight, bottomLeft, bottomRight, center }

class WatermarkSettings {
  const WatermarkSettings({
    this.text = '',
    this.enabled = false,
    this.margin = 0.03,
    this.scale = 0.06,
    this.opacity = 0.6,
    this.corner = WatermarkCorner.bottomRight,
    this.color = const Color(0xFFFFFFFF),
  });

  final String text;
  final bool enabled;
  final double margin;
  final double scale;
  final double opacity;
  final WatermarkCorner corner;
  final Color color;

  bool get active => enabled && text.trim().isNotEmpty;

  WatermarkSettings copyWith({
    String? text,
    bool? enabled,
    double? margin,
    double? scale,
    double? opacity,
    WatermarkCorner? corner,
    Color? color,
  }) => WatermarkSettings(
    text: text ?? this.text,
    enabled: enabled ?? this.enabled,
    margin: margin ?? this.margin,
    scale: scale ?? this.scale,
    opacity: opacity ?? this.opacity,
    corner: corner ?? this.corner,
    color: color ?? this.color,
  );

  Map<String, dynamic> toJson() => {
    't': text,
    'e': enabled,
    'm': margin,
    's': scale,
    'o': opacity,
    'c': corner.name,
    'col': color.toARGB32(),
  };

  static WatermarkSettings fromJson(Map<String, dynamic>? j) {
    if (j == null) return const WatermarkSettings();
    final col = j['col'];
    return WatermarkSettings(
      text: (j['t'] as String?) ?? '',
      enabled: (j['e'] as bool?) ?? false,
      margin: (j['m'] as num?)?.toDouble() ?? 0.03,
      scale: (j['s'] as num?)?.toDouble() ?? 0.06,
      opacity: (j['o'] as num?)?.toDouble() ?? 0.6,
      corner: WatermarkCorner.values.firstWhere(
        (c) => c.name == j['c'],
        orElse: () => WatermarkCorner.bottomRight,
      ),
      color: col is int ? Color(col) : const Color(0xFFFFFFFF),
    );
  }
}

class ResizeSettings extends ChangeNotifier {
  ResizeSettings() {
    _hydrateFrom(_memoryCache);
  }

  static Map<String, dynamic>? _memoryCache;

  // --- Geometry ---------------------------------------------------------
  ResizeMode _mode = ResizeMode.longestSide;
  int _width = 1920;
  int _height = 1920;
  int _percent = 50;
  bool _allowUpscale = false;
  bool _linkDimensions = true;
  String? _presetName;
  String? _folderPresetName;

  // --- Output -----------------------------------------------------------
  OutputFormat _format = OutputFormat.keep;
  int _quality = 85;
  int? _targetKb;
  int _pngLevel = 6;
  bool _webpLossless = false;
  int _webpMethod = 4;
  ChromaMode _chroma = ChromaMode.yuv444;
  bool _stripMetadata = true;
  bool _autoRotate = true;
  bool _progressive = true;
  bool _preserveAnimation = true;

  // --- Transforms -------------------------------------------------------
  int _rotateQuarterTurns = 0;
  bool _flipH = false;
  bool _flipV = false;
  Color _padColor = const Color(0xFFFFFFFF);

  // --- Adjustments ------------------------------------------------------
  Adjustments _adjustments = const Adjustments();
  double _grayscale = 0;
  double _sepia = 0;
  double _blurRadius = 0;
  double _sharpenAmount = 0;

  // --- Naming / output --------------------------------------------------
  WatermarkSettings _watermark = const WatermarkSettings();
  String _nameTemplate = '{name}';
  String _outputDirectory = '';
  bool _overwrite = false;
  bool _keepExtensionWhenKeepFormat = true;

  static const _templateTokens = <String>[
    '{name}',
    '{w}',
    '{h}',
    '{origw}',
    '{origh}',
    '{index}',
    '{ext}',
    '{preset}',
  ];

  List<String> get templateTokens => _templateTokens;

  // ---------------------------------------------------------------- getters
  ResizeMode get mode => _mode;
  int get width => _width;
  int get height => _height;
  int get percent => _percent;
  bool get allowUpscale => _allowUpscale;
  bool get linkDimensions => _linkDimensions;
  String? get presetName => _presetName;
  String? get folderPresetName => _folderPresetName;

  OutputFormat get format => _format;
  int get quality => _quality;
  int? get targetKb => _targetKb;
  int get pngLevel => _pngLevel;
  bool get webpLossless => _webpLossless;
  int get webpMethod => _webpMethod;
  ChromaMode get chroma => _chroma;
  bool get stripMetadata => _stripMetadata;
  bool get autoRotate => _autoRotate;
  bool get progressive => _progressive;
  bool get preserveAnimation => _preserveAnimation;

  int get rotateQuarterTurns => _rotateQuarterTurns;
  bool get flipH => _flipH;
  bool get flipV => _flipV;
  Color get padColor => _padColor;

  Adjustments get adjustments => _adjustments;
  double get grayscale => _grayscale;
  double get sepia => _sepia;
  double get blurRadius => _blurRadius;
  double get sharpenAmount => _sharpenAmount;

  WatermarkSettings get watermark => _watermark;
  String get nameTemplate => _nameTemplate;
  String get outputDirectory => _outputDirectory;
  bool get overwrite => _overwrite;
  bool get keepExtensionWhenKeepFormat => _keepExtensionWhenKeepFormat;

  ResizeSpec get spec => ResizeSpec(
    mode: _mode,
    width: _width,
    height: _height,
    percent: _percent,
    allowUpscale: _allowUpscale,
  );

  bool get qualityIsAutomatic => _targetKb != null;

  // ---------------------------------------------------------------- setters
  void setMode(ResizeMode v) {
    if (v == _mode) return;
    _mode = v;
    _presetName = null;
    notifyListeners();
  }

  void setWidth(int v) {
    final clamped = v < 1 ? 1 : v;
    if (clamped == _width) return;
    _width = clamped;
    if (_linkDimensions && _mode != ResizeMode.width) {
      // keep ratio from the last known source when available
      final ratio = _aspectHint;
      if (ratio != null) _height = ((clamped / ratio).round()).clamp(1, 100000);
    }
    _presetName = null;
    notifyListeners();
  }

  void setHeight(int v) {
    final clamped = v < 1 ? 1 : v;
    if (clamped == _height) return;
    _height = clamped;
    if (_linkDimensions && _mode != ResizeMode.height) {
      final ratio = _aspectHint;
      if (ratio != null) _width = ((clamped * ratio).round()).clamp(1, 100000);
    }
    _presetName = null;
    notifyListeners();
  }

  double? _aspectHint;

  /// Lets the linked width/height fields follow the currently selected image.
  void setAspectHint(double? ratio) {
    _aspectHint = (ratio != null && ratio > 0) ? ratio : null;
  }

  void setPercent(int v) {
    final clamped = v.clamp(1, 1000);
    if (clamped == _percent) return;
    _percent = clamped;
    _presetName = null;
    notifyListeners();
  }

  void setAllowUpscale(bool v) {
    if (v == _allowUpscale) return;
    _allowUpscale = v;
    notifyListeners();
  }

  void setLinkDimensions(bool v) {
    if (v == _linkDimensions) return;
    _linkDimensions = v;
    notifyListeners();
  }

  void setFormat(OutputFormat v) {
    if (v == _format) return;
    _format = v;
    if (!v.supportsQuality) _targetKb = null;
    notifyListeners();
  }

  void setQuality(int v) {
    final clamped = v.clamp(1, 100);
    if (clamped == _quality) return;
    _quality = clamped;
    _targetKb = null;
    notifyListeners();
  }

  void setTargetKb(int? v) {
    if (v == null) {
      if (_targetKb == null) return;
      _targetKb = null;
      notifyListeners();
      return;
    }
    final next = v < 1 ? null : v;
    if (next == _targetKb) return;
    _targetKb = next;
    notifyListeners();
  }

  void setPngLevel(int v) {
    final c = v.clamp(0, 9);
    if (c == _pngLevel) return;
    _pngLevel = c;
    notifyListeners();
  }

  void setWebpLossless(bool v) {
    if (v == _webpLossless) return;
    _webpLossless = v;
    notifyListeners();
  }

  void setWebpMethod(int v) {
    final c = v.clamp(0, 6);
    if (c == _webpMethod) return;
    _webpMethod = c;
    notifyListeners();
  }

  void setChroma(ChromaMode v) {
    if (v == _chroma) return;
    _chroma = v;
    notifyListeners();
  }

  void setStripMetadata(bool v) {
    if (v == _stripMetadata) return;
    _stripMetadata = v;
    notifyListeners();
  }

  void setAutoRotate(bool v) {
    if (v == _autoRotate) return;
    _autoRotate = v;
    notifyListeners();
  }

  void setProgressive(bool v) {
    if (v == _progressive) return;
    _progressive = v;
    notifyListeners();
  }

  /// When off, an animated GIF or WebP is deliberately collapsed to its first
  /// frame. Default on: flattening an animation is silent data loss.
  void setPreserveAnimation(bool v) {
    if (v == _preserveAnimation) return;
    _preserveAnimation = v;
    notifyListeners();
  }

  void rotateBy(int quarterTurns) {
    _rotateQuarterTurns = (_rotateQuarterTurns + quarterTurns) % 4;
    notifyListeners();
  }

  void resetRotation() {
    if (_rotateQuarterTurns == 0) return;
    _rotateQuarterTurns = 0;
    notifyListeners();
  }

  void setFlipH(bool v) {
    if (v == _flipH) return;
    _flipH = v;
    notifyListeners();
  }

  void setFlipV(bool v) {
    if (v == _flipV) return;
    _flipV = v;
    notifyListeners();
  }

  void setPadColor(Color v) {
    if (v.toARGB32() == _padColor.toARGB32()) return;
    _padColor = v;
    notifyListeners();
  }

  void setAdjustments(Adjustments v) {
    _adjustments = v;
    notifyListeners();
  }

  void resetAdjustments() {
    _adjustments = const Adjustments();
    notifyListeners();
  }

  void setGrayscale(double v) {
    if (v == _grayscale) return;
    _grayscale = v;
    notifyListeners();
  }

  void setSepia(double v) {
    if (v == _sepia) return;
    _sepia = v;
    notifyListeners();
  }

  void setBlurRadius(double v) {
    if (v == _blurRadius) return;
    _blurRadius = v;
    notifyListeners();
  }

  void setSharpenAmount(double v) {
    if (v == _sharpenAmount) return;
    _sharpenAmount = v;
    notifyListeners();
  }

  void setWatermark(WatermarkSettings v) {
    _watermark = v;
    notifyListeners();
  }

  void setNameTemplate(String v) {
    if (v == _nameTemplate) return;
    _nameTemplate = v.isEmpty ? '{name}' : v;
    notifyListeners();
  }

  void setOutputDirectory(String v) {
    final norm = v.trim();
    if (norm == _outputDirectory) return;
    _outputDirectory = norm;
    notifyListeners();
  }

  void setOverwrite(bool v) {
    if (v == _overwrite) return;
    _overwrite = v;
    notifyListeners();
  }

  void setKeepExtensionWhenKeepFormat(bool v) {
    if (v == _keepExtensionWhenKeepFormat) return;
    _keepExtensionWhenKeepFormat = v;
    notifyListeners();
  }

  // ------------------------------------------------------------- presets
  void applyPreset(ResizePreset p) {
    _presetName = p.name;
    _mode = p.mode;
    if (p.width != null) _width = p.width!;
    if (p.height != null) _height = p.height!;
    if (p.format != null) _format = OutputFormat.fromExtension(p.format);
    if (p.quality != null) {
      _quality = p.quality!;
      _targetKb = null;
    }
    _targetKb = p.targetKb;
    _aspectHint = null;
    notifyListeners();
  }

  /// Loads a named preset but keeps the user's chosen output format/quality.
  void applyFolderPreset(ResizePreset p) {
    _folderPresetName = p.name;
    applyPreset(p);
    _folderPresetName = p.name;
    notifyListeners();
  }

  void clearPreset() {
    if (_presetName == null) return;
    _presetName = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ persistence
  Map<String, dynamic> toJson() => {
    'v': 1,
    'mode': _mode.name,
    'w': _width,
    'h': _height,
    'pct': _percent,
    'up': _allowUpscale,
    'link': _linkDimensions,
    'preset': _presetName,
    'fpreset': _folderPresetName,
    'fmt': _format.name,
    'q': _quality,
    'kb': _targetKb,
    'pnglvl': _pngLevel,
    'webl': _webpLossless,
    'webm': _webpMethod,
    'chroma': _chroma.name,
    'strip': _stripMetadata,
    'autorot': _autoRotate,
    'prog': _progressive,
    'anim': _preserveAnimation,
    'rot': _rotateQuarterTurns,
    'fh': _flipH,
    'fv': _flipV,
    'pad': _padColor.toARGB32(),
    'adj': _adjustments.toJson(),
    'gray': _grayscale,
    'sepia': _sepia,
    'blur': _blurRadius,
    'sharp': _sharpenAmount,
    'wm': _watermark.toJson(),
    'tmpl': _nameTemplate,
    'outdir': _outputDirectory,
    'ow': _overwrite,
    'keepext': _keepExtensionWhenKeepFormat,
  };

  void _hydrateFrom(Map<String, dynamic>? j) {
    if (j == null) return;
    _resetToDefaults();
    _mode = ResizeMode.values.firstWhere(
      (m) => m.name == j['mode'],
      orElse: () => _mode,
    );
    _width = (j['w'] as num?)?.toInt() ?? _width;
    _height = (j['h'] as num?)?.toInt() ?? _height;
    _percent = (j['pct'] as num?)?.toInt() ?? _percent;
    _allowUpscale = (j['up'] as bool?) ?? _allowUpscale;
    _linkDimensions = (j['link'] as bool?) ?? _linkDimensions;
    _presetName = j['preset'] as String?;
    _folderPresetName = j['fpreset'] as String?;
    _format = OutputFormat.values.firstWhere(
      (f) => f.name == j['fmt'],
      orElse: () => _format,
    );
    _quality = ((j['q'] as num?)?.toInt() ?? _quality).clamp(1, 100);
    _targetKb = (j['kb'] as num?)?.toInt();
    _pngLevel = ((j['pnglvl'] as num?)?.toInt() ?? _pngLevel).clamp(0, 9);
    _webpLossless = (j['webl'] as bool?) ?? _webpLossless;
    _webpMethod = ((j['webm'] as num?)?.toInt() ?? _webpMethod).clamp(0, 6);
    _chroma = ChromaMode.values.firstWhere(
      (c) => c.name == j['chroma'],
      orElse: () => _chroma,
    );
    _stripMetadata = (j['strip'] as bool?) ?? _stripMetadata;
    _autoRotate = (j['autorot'] as bool?) ?? _autoRotate;
    _progressive = (j['prog'] as bool?) ?? _progressive;
    _preserveAnimation = (j['anim'] as bool?) ?? _preserveAnimation;
    _rotateQuarterTurns = ((j['rot'] as num?)?.toInt() ?? 0) % 4;
    _flipH = (j['fh'] as bool?) ?? _flipH;
    _flipV = (j['fv'] as bool?) ?? _flipV;
    final pad = j['pad'];
    if (pad is int) _padColor = Color(pad);
    _adjustments = Adjustments.fromJson(j['adj'] as Map<String, dynamic>?);
    _grayscale = (j['gray'] as num?)?.toDouble() ?? _grayscale;
    _sepia = (j['sepia'] as num?)?.toDouble() ?? _sepia;
    _blurRadius = (j['blur'] as num?)?.toDouble() ?? _blurRadius;
    _sharpenAmount = (j['sharp'] as num?)?.toDouble() ?? _sharpenAmount;
    _watermark = WatermarkSettings.fromJson(j['wm'] as Map<String, dynamic>?);
    _nameTemplate = (j['tmpl'] as String?) ?? _nameTemplate;
    _outputDirectory = (j['outdir'] as String?) ?? _outputDirectory;
    _overwrite = (j['ow'] as bool?) ?? _overwrite;
    _keepExtensionWhenKeepFormat =
        (j['keepext'] as bool?) ?? _keepExtensionWhenKeepFormat;
  }

  static const _storeKey = 'pixelforge.settings.v1';

  void _resetToDefaults() {
    _mode = ResizeMode.longestSide;
    _width = 1920;
    _height = 1920;
    _percent = 50;
    _allowUpscale = false;
    _linkDimensions = true;
    _presetName = null;
    _folderPresetName = null;
    _format = OutputFormat.keep;
    _quality = 85;
    _targetKb = null;
    _pngLevel = 6;
    _webpLossless = false;
    _webpMethod = 4;
    _chroma = ChromaMode.yuv444;
    _stripMetadata = true;
    _autoRotate = true;
    _progressive = true;
    _preserveAnimation = true;
    _rotateQuarterTurns = 0;
    _flipH = false;
    _flipV = false;
    _padColor = const Color(0xFFFFFFFF);
    _adjustments = const Adjustments();
    _grayscale = 0;
    _sepia = 0;
    _blurRadius = 0;
    _sharpenAmount = 0;
    _watermark = const WatermarkSettings();
    _nameTemplate = '{name}';
    _outputDirectory = '';
    _overwrite = false;
    _keepExtensionWhenKeepFormat = true;
    _aspectHint = null;
  }

  /// Applies a previously captured [toJson] snapshot without touching storage.
  void loadFrom(Map<String, dynamic> json) {
    _hydrateFrom(json);
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw == null) return;
      _memoryCache = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    _hydrateFrom(_memoryCache);
    notifyListeners();
  }

  Future<void> save() async {
    try {
      _memoryCache = toJson();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey, jsonEncode(_memoryCache));
    } catch (_) {
      // persistence is best-effort; never block the pipeline on it
    }
  }
}
