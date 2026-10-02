import 'dart:async';

import 'package:flutter/foundation.dart';

import 'engine.dart';
import 'job.dart';
import 'picker.dart';
import 'saver/saver.dart';
import 'settings.dart';

/// Owns the queue and drives the batch pipeline.
class ResizeController extends ChangeNotifier {
  ResizeController({ResizeSettings? settings})
    : settings = settings ?? ResizeSettings(),
      _sink = createOutputSink();

  final ResizeSettings settings;
  final OutputSink _sink;

  final List<ImageJob> _jobs = <ImageJob>[];
  List<ImageJob> get jobs => List.unmodifiable(_jobs);

  bool _busy = false;
  bool get busy => _busy;

  String? _selectedId;
  String? get selectedId => _selectedId;

  ImageJob? get selected {
    if (_selectedId == null) return null;
    for (final j in _jobs) {
      if (j.id == _selectedId) return j;
    }
    return null;
  }

  int get doneCount => _jobs.where((j) => j.status == JobStatus.done).length;
  int get failedCount =>
      _jobs.where((j) => j.status == JobStatus.failed).length;
  int get pendingCount => _jobs
      .where(
        (j) => j.status == JobStatus.queued || j.status == JobStatus.failed,
      )
      .length;

  int get totalInputBytes => _jobs.fold(0, (a, j) => a + j.inputBytes);
  int get totalOutputBytes => _jobs.fold(
    0,
    (a, j) => a + (j.status == JobStatus.done ? (j.outputBytes ?? 0) : 0),
  );

  double? get overallSavedRatio {
    final out = totalOutputBytes;
    final inp = totalInputBytes;
    if (out == 0 || inp == 0) return null;
    return 1 - (out / inp);
  }

  void _changed() => notifyListeners();

  void select(String? id) {
    _selectedId = id;
    _changed();
  }

  // ------------------------------------------------------------- queue edits
  Future<int> addViaPicker() async {
    if (_busy) return 0;
    final files = await SourcePicker.pickFiles();
    if (files.isEmpty) return 0;
    return _ingest(files);
  }

  int _ingest(List<({String name, Uint8List bytes, String? path})> files) {
    final added = SourcePicker.addToQueue(_jobs, files);
    if (added > 0) {
      _selectedId ??= _jobs.first.id;
      _probeAll();
      _changed();
    }
    return added;
  }

  void addDroppedFiles(
    List<({String name, Uint8List bytes, String? path})> files,
  ) {
    if (_busy) return;
    _ingest(files);
  }

  void _probeAll() {
    for (final job in _jobs) {
      if (job.sourceWidth != null) continue;
      try {
        final info = ResizeEngine.probe(job.bytes, name: job.name);
        job.markProbed(info.width, info.height);
      } catch (_) {
        // Left as unknown; the run phase reports the real error.
      }
    }
  }

  void removeJob(String id) {
    if (_busy) return;
    _jobs.removeWhere((j) => j.id == id);
    if (_selectedId == id) {
      _selectedId = _jobs.isEmpty ? null : _jobs.first.id;
    }
    _changed();
  }

  void clearFinished() {
    if (_busy) return;
    _jobs.removeWhere((j) => j.status == JobStatus.done);
    if (selected == null) _selectedId = _jobs.isEmpty ? null : _jobs.first.id;
    _changed();
  }

  void clearAll() {
    if (_busy) return;
    _jobs.clear();
    _selectedId = null;
    _changed();
  }

  void resetQueue() {
    if (_busy) return;
    for (final j in _jobs) {
      j.reset();
    }
    _changed();
  }

  // ----------------------------------------------------------------- naming
  String baseNameOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) return fileName;
    return fileName.substring(0, dot);
  }

  Future<String> resolveOutputName(ImageJob job, int index) async {
    final bytes = job.output;
    final ext = ResizeEngine.extensionOfName(job.name) ?? 'jpg';
    final outExt = _outputExtension(ext);
    var base = renderTemplate(
      settings.nameTemplate,
      baseName: baseNameOf(job.name),
      outWidth: job.outWidth ?? job.sourceWidth ?? 0,
      outHeight: job.outHeight ?? job.sourceHeight ?? 0,
      srcWidth: job.sourceWidth ?? 0,
      srcHeight: job.sourceHeight ?? 0,
      extension: outExt,
      index: index,
      presetName: settings.presetName,
    );

    if (settings.overwrite) return '$base.$outExt';

    var candidate = '$base.$outExt';
    if (bytes == null) return candidate;
    var n = 1;
    while (await _sink.exists(candidate, directory: _outDir)) {
      candidate = '$base ($n).$outExt';
      n++;
      if (n > 9999) break;
    }
    return candidate;
  }

  String _outputExtension(String sourceExt) {
    if (settings.format == OutputFormat.keep) {
      if (settings.keepExtensionWhenKeepFormat) {
        return sourceExt;
      }
      return 'jpg';
    }
    return settings.format.extension!;
  }

  String? get _outDir {
    final d = settings.outputDirectory.trim();
    return d.isEmpty ? null : d;
  }

  bool get canPickDirectory => _sink.supportsDirectory;

  Future<void> chooseOutputDirectory() async {
    final dir = await SourcePicker.pickDirectory();
    if (dir != null) settings.setOutputDirectory(dir);
  }

  // ---------------------------------------------------------------- pipeline
  Future<void> runBatch() async {
    if (_busy) return;
    final targets = _jobs.where((j) => j.status != JobStatus.done).toList();
    if (targets.isEmpty) return;

    _busy = true;
    _changed();

    final snapshot = settings.toJson();
    final runSettings = ResizeSettings()..loadFrom(snapshot);

    try {
      for (var i = 0; i < targets.length; i++) {
        final job = targets[i];
        job.markRunning(0.0);
        _changed();
        await processJob(job, runSettings);
        _changed();
      }
    } finally {
      _busy = false;
      _changed();
    }
  }

  Future<int> saveAll() async {
    final done = _jobs
        .where((j) => j.status == JobStatus.done && j.output != null)
        .toList();
    if (done.isEmpty) return 0;

    var written = 0;
    for (var i = 0; i < done.length; i++) {
      final job = done[i];
      final bytes = job.output;
      if (bytes == null) continue;
      final name = await resolveOutputName(job, i + 1);
      if (await _sink.saveBytes(bytes, name, directory: _outDir)) written++;
    }
    return written;
  }

  @override
  void dispose() {
    settings.dispose();
    for (final j in _jobs) {
      j.dispose();
    }
    super.dispose();
  }
}
