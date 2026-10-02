import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'engine.dart';
import 'job.dart';

/// Reads user-selected images into memory. One API for Android, iOS, Windows,
/// macOS, Linux and web.
class SourcePicker {
  const SourcePicker._();

  static const int maxFileBytes = 120 * 1024 * 1024;

  static Future<List<({String name, Uint8List bytes, String? path})>>
  pickFiles() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select images',
      type: FileType.custom,
      allowedExtensions: supportedInputExtensions,
    );
    if (result.isEmpty) return const [];

    final out = <({String name, Uint8List bytes, String? path})>[];
    for (final f in result) {
      final declared = f.lengthSync();
      if (declared != null && declared > maxFileBytes) continue;
      try {
        final bytes = await f.readAsBytes();
        if (bytes.isEmpty || bytes.lengthInBytes > maxFileBytes) continue;
        out.add((name: f.name, bytes: bytes, path: f.path));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  /// Adds picked files to [jobs] as queued entries.
  static int addToQueue(
    List<ImageJob> jobs,
    List<({String name, Uint8List bytes, String? path})> files,
  ) {
    final start = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      jobs.add(
        ImageJob(id: '${start}_$i', name: f.name, bytes: f.bytes, path: f.path),
      );
    }
    return files.length;
  }

  static Future<String?> pickDirectory() async {
    try {
      return await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose output folder',
      );
    } catch (_) {
      return null;
    }
  }
}
