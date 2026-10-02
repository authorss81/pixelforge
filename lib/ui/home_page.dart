import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/engine.dart';
import '../core/job.dart';
import '../core/picker.dart';
import '../core/resize_mode.dart';
import '../core/settings.dart';
import 'theme.dart';
import 'widgets/preview.dart';
import 'widgets/queue_view.dart';
import 'widgets/settings_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final ResizeController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _pane = 0;
  bool _dragging = false;

  ResizeController get controller => widget.controller;

  static const _wideBreakpoint = 980.0;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDrop,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Scaffold(
            appBar: _buildAppBar(context),
            body: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= _wideBreakpoint;
                    return wide ? _buildWide() : _buildNarrow();
                  },
                ),
                if (_dragging) const _DropOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.crop_free_rounded,
              size: 17,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'PixelForge',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'No network permission. Images never leave this device.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Add images',
          onPressed: controller.busy ? null : _addFiles,
          icon: const Icon(Icons.add_photo_alternate_outlined),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () {
            controller.settings.save();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings saved'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          icon: const Icon(Icons.save_outlined),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: theme.dividerColor),
      ),
    );
  }

  Widget _buildWide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 330,
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: QueueView(controller: controller),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _PreviewPane(controller: controller),
          ),
        ),
        SizedBox(
          width: 360,
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
            child: Column(
              children: [
                const PaneHeader('Output settings', icon: Icons.tune),
                Expanded(child: SettingsView(controller: controller)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow() {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _pane,
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: QueueView(controller: controller),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: _PreviewPane(controller: controller),
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: Column(
                  children: [
                    const PaneHeader('Output settings', icon: Icons.tune),
                    Expanded(child: SettingsView(controller: controller)),
                  ],
                ),
              ),
            ],
          ),
        ),
        NavigationBar(
          height: 62,
          selectedIndex: _pane,
          onDestinationSelected: (i) => setState(() => _pane = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library),
              label: 'Queue',
            ),
            NavigationDestination(
              icon: Icon(Icons.preview_outlined),
              selectedIcon: Icon(Icons.preview),
              label: 'Preview',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Settings',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addFiles() async {
    await controller.addViaPicker();
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    final files = <({String name, Uint8List bytes, String? path})>[];
    await _collect(details.files, files, 0);
    if (files.isEmpty || !mounted) return;

    controller.addDroppedFiles(files);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${files.length} file${files.length == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  /// Flattens dropped items, walking into directories up to 3 levels deep.
  Future<void> _collect(
    List<DropItem> items,
    List<({String name, Uint8List bytes, String? path})> out,
    int depth,
  ) async {
    if (depth > 3 || out.length >= 400) return;
    for (final item in items) {
      if (item is DropItemDirectory) {
        await _collect(item.children, out, depth + 1);
        continue;
      }
      final ext = ResizeEngine.extensionOfName(item.name) ?? '';
      if (!supportedInputExtensions.contains(ext)) continue;
      try {
        final bytes = await item.readAsBytes();
        if (bytes.isEmpty || bytes.lengthInBytes > SourcePicker.maxFileBytes) {
          continue;
        }
        out.add((name: item.name, bytes: bytes, path: item.path));
      } catch (_) {
        continue;
      }
    }
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        color: scheme.primary.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.primary, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.file_download_outlined,
                size: 42,
                color: scheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Drop to add',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Folders are walked up to 3 levels deep',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPane extends StatefulWidget {
  const _PreviewPane({required this.controller});

  final ResizeController controller;

  @override
  State<_PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<_PreviewPane> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final job = controller.selected;
    final theme = Theme.of(context);

    final bytes = job == null
        ? null
        : (_showOriginal ? job.bytes : (job.output ?? job.bytes));
    final label = job == null
        ? null
        : (_showOriginal
              ? 'Original'
              : (job.output != null ? 'Result' : 'Preview'));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaneHeader(
            job?.name ?? 'Preview',
            icon: Icons.preview_outlined,
            subtitle: job == null
                ? 'Nothing selected'
                : '${job.sourceSizeLabel}  ·  ${formatBytes(job.inputBytes)}',
            trailing: job == null
                ? null
                : SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Before', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('After', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_showOriginal},
                    onSelectionChanged: (s) =>
                        setState(() => _showOriginal = s.first),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LargePreview(bytes: bytes, label: label),
            ),
          ),
          if (job != null) _ResultBar(job: job, controller: controller),
          if (job == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Add images, choose an output size, then press Process. '
                'Everything runs on this device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({required this.job, required this.controller});

  final ImageJob job;
  final ResizeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = controller.settings;
    final predicted = computeTargetSize(
      s.spec,
      job.sourceWidth ?? 0,
      job.sourceHeight ?? 0,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Stat(label: 'Target', value: '$predicted', icon: Icons.crop),
          _Stat(
            label: 'Format',
            value: job.output != null
                ? _extOf(job)
                : (s.format == OutputFormat.keep
                      ? 'keep'
                      : s.format.extension!.toUpperCase()),
            icon: Icons.description_outlined,
          ),
          if (job.output != null)
            _Stat(
              label: 'Size',
              value: formatBytes(job.outputBytes),
              icon: Icons.sd_storage_outlined,
              highlight: true,
            ),
          if (job.output != null)
            _Stat(
              label: 'Quality',
              value: job.solvedQuality?.toString() ?? 'lossless',
              icon: Icons.tune,
            ),
          if (job.savedRatio != null && job.savedRatio! > 0)
            _Stat(
              label: 'Saved',
              value: '-${(job.savedRatio! * 100).round()}%',
              icon: Icons.savings_outlined,
              highlight: true,
            ),
        ],
      ),
    );
  }

  static String _extOf(ImageJob job) {
    final src = ResizeEngine.extensionOfName(job.name) ?? 'jpg';
    return src.toUpperCase();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
