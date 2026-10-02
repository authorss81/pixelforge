import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/engine.dart';

/// Lazily generated, once-per-mount preview thumbnail.
class ImageThumb extends StatefulWidget {
  const ImageThumb({
    super.key,
    required this.bytes,
    this.maxDim = 128,
    this.fit = BoxFit.cover,
    this.borderRadius = 8,
  });

  final Uint8List bytes;
  final int maxDim;
  final BoxFit fit;
  final double borderRadius;

  @override
  State<ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<ImageThumb> {
  Future<Uint8List?>? _future;
  String? _token;

  @override
  void didUpdateWidget(ImageThumb old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) _start();
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final token = '${widget.bytes.length}:${widget.maxDim}';
    if (_token == token && _future != null) return;
    _token = token;
    _future = computeThumb(widget.bytes, widget.maxDim);
  }

  static Future<Uint8List?> computeThumb(Uint8List b, int dim) async {
    return ResizeEngine.thumbnail(b, maxDim: dim);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: FutureBuilder<Uint8List?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox.expand(
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                ),
              );
            }
            final data = snap.data;
            if (data == null || data.isEmpty) {
              return const SizedBox.expand(
                child: Icon(Icons.broken_image_outlined, size: 18),
              );
            }
            return Image.memory(data, fit: widget.fit, gaplessPlayback: true);
          },
        ),
      ),
    );
  }
}

/// A big, centred before/after preview.
class LargePreview extends StatelessWidget {
  const LargePreview({
    super.key,
    required this.bytes,
    this.label,
    this.icon = Icons.image_outlined,
  });

  final Uint8List? bytes;
  final String? label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = bytes;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (data == null || data.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nothing to preview',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            InteractiveViewer(
              maxScale: 12,
              child: Image.memory(data, fit: BoxFit.contain),
            ),
          if (label != null)
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.scrim.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  label!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
