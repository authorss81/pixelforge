import 'package:flutter/foundation.dart';

enum JobStatus { queued, running, done, failed, skipped }

class ImageJob extends ChangeNotifier {
  ImageJob({
    required this.id,
    required this.name,
    required this.bytes,
    this.path,
  });

  final String id;
  final String name;
  final Uint8List bytes;
  final String? path;

  JobStatus _status = JobStatus.queued;
  Uint8List? _output;
  String? _error;
  int? _sourceWidth;
  int? _sourceHeight;
  int? _outWidth;
  int? _outHeight;
  int? _solvedQuality;
  double _progress = 0;

  JobStatus get status => _status;
  Uint8List? get output => _output;
  String? get error => _error;
  int? get sourceWidth => _sourceWidth;
  int? get sourceHeight => _sourceHeight;
  int? get outWidth => _outWidth;
  int? get outHeight => _outHeight;
  int? get solvedQuality => _solvedQuality;
  double get progress => _progress;

  int get inputBytes => bytes.length;
  int? get outputBytes => _output?.length;

  double? get savedRatio {
    final o = _output?.length;
    if (o == null || bytes.isEmpty) return null;
    return 1 - (o / bytes.length);
  }

  String get sourceSizeLabel {
    final w = _sourceWidth;
    final h = _sourceHeight;
    if (w == null || h == null) return '-';
    return '$w x $h';
  }

  String get outputSizeLabel {
    final w = _outWidth;
    final h = _outHeight;
    if (w == null || h == null) return '-';
    return '$w x $h';
  }

  void markProbed(int w, int h) {
    _sourceWidth = w;
    _sourceHeight = h;
    notifyListeners();
  }

  void markRunning(double progress) {
    _status = JobStatus.running;
    _progress = progress;
    notifyListeners();
  }

  void markDone({
    required Uint8List output,
    required int width,
    required int height,
    int? quality,
  }) {
    _output = output;
    _outWidth = width;
    _outHeight = height;
    _solvedQuality = quality;
    _status = JobStatus.done;
    _progress = 1;
    _error = null;
    notifyListeners();
  }

  void markFailed(String message) {
    _error = message;
    _status = JobStatus.failed;
    _progress = 1;
    notifyListeners();
  }

  void markSkipped(String reason) {
    _error = reason;
    _status = JobStatus.skipped;
    _progress = 1;
    notifyListeners();
  }

  void reset() {
    _status = JobStatus.queued;
    _output = null;
    _error = null;
    _progress = 0;
    _solvedQuality = null;
    notifyListeners();
  }
}

String formatBytes(int? bytes) {
  if (bytes == null) return '-';
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) return '${(bytes / 1000).toStringAsFixed(1)} KB';
  if (bytes < 1000 * 1000 * 1000) {
    return '${(bytes / 1000000).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1000000000).toStringAsFixed(2)} GB';
}

int extensionToDotsPerInch(String? ext) {
  switch (ext?.toLowerCase().replaceAll('.', '')) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'tif':
    case 'tiff':
    case 'webp':
      return 300;
    case 'bmp':
    case 'gif':
    case 'ico':
      return 72;
    default:
      return 96;
  }
}
