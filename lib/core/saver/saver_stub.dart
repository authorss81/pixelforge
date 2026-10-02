import 'dart:typed_data';

/// Fallback used only when neither `dart:io` nor `dart:js_interop` exists.
class OutputSink {
  const OutputSink();

  bool get supportsDirectory => false;

  Future<bool> exists(String fileName, {String? directory}) async => false;

  Future<bool> saveBytes(
    Uint8List bytes,
    String fileName, {
    String? directory,
  }) async => false;

  Future<List<String>> saveAll(
    List<({Uint8List bytes, String fileName})> items, {
    String? directory,
  }) async => const <String>[];
}

OutputSink createOutputSink() => const OutputSink();
