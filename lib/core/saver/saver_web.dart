import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browser variant: hands each file to the download manager.
class OutputSink {
  const OutputSink();

  bool get supportsDirectory => false;

  Future<bool> exists(String fileName, {String? directory}) async => false;

  Future<bool> saveBytes(
    Uint8List bytes,
    String fileName, {
    String? directory,
  }) async {
    // Copy into a fresh buffer so the blob keeps its own backing store.
    final blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: _mimeFor(fileName)),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return true;
  }

  Future<List<String>> saveAll(
    List<({Uint8List bytes, String fileName})> items, {
    String? directory,
  }) async {
    for (final item in items) {
      await saveBytes(item.bytes, item.fileName);
    }
    return items.map((e) => e.fileName).toList();
  }

  static String _mimeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'tif':
      case 'tiff':
        return 'image/tiff';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'application/octet-stream';
    }
  }
}

OutputSink createOutputSink() => const OutputSink();
