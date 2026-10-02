import 'dart:io';
import 'dart:typed_data';

/// Writes finished images to disk. Never touches the network.
class OutputSink {
  const OutputSink();

  bool get supportsDirectory => true;

  Future<bool> exists(String fileName, {String? directory}) async {
    final dir = (directory == null || directory.isEmpty)
        ? Directory.current.path
        : directory;
    return File('$dir${Platform.pathSeparator}$fileName').exists();
  }

  Future<bool> saveBytes(
    Uint8List bytes,
    String fileName, {
    String? directory,
  }) async {
    final dir = (directory == null || directory.isEmpty)
        ? Directory.current.path
        : directory;
    final target = File('$dir${Platform.pathSeparator}$fileName');
    try {
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> saveAll(
    List<({Uint8List bytes, String fileName})> items, {
    String? directory,
  }) async {
    final written = <String>[];
    for (final item in items) {
      if (await saveBytes(item.bytes, item.fileName, directory: directory)) {
        written.add(item.fileName);
      }
    }
    return written;
  }
}

OutputSink createOutputSink() => const OutputSink();
