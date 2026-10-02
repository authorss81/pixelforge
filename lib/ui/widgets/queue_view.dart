import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../../core/job.dart';
import '../theme.dart';
import 'preview.dart';

class QueueView extends StatelessWidget {
  const QueueView({super.key, required this.controller});

  final ResizeController controller;

  @override
  Widget build(BuildContext context) {
    final jobs = controller.jobs;
    final theme = Theme.of(context);

    return Column(
      children: [
        PaneHeader(
          'Queue',
          icon: Icons.photo_library_outlined,
          subtitle: jobs.isEmpty
              ? 'No images yet'
              : '${jobs.length} file${jobs.length == 1 ? '' : 's'}  ·  ${formatBytes(controller.totalInputBytes)}',
          trailing: jobs.isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Re-run everything',
                      onPressed: controller.busy ? null : controller.resetQueue,
                      icon: const Icon(Icons.refresh, size: 18),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Queue actions',
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (v) {
                        switch (v) {
                          case 'clearDone':
                            controller.clearFinished();
                          case 'clearAll':
                            controller.clearAll();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'clearDone',
                          child: Text('Remove finished'),
                        ),
                        PopupMenuItem(
                          value: 'clearAll',
                          child: Text('Clear all'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        Expanded(
          child: jobs.isEmpty
              ? const _EmptyQueue()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, i) {
                    final job = jobs[i];
                    return _JobTile(
                      key: ValueKey(job.id),
                      job: job,
                      selected: controller.selectedId == job.id,
                      onTap: () => controller.select(job.id),
                      onRemove: () => controller.removeJob(job.id),
                      enabled: !controller.busy,
                    );
                  },
                ),
        ),
        _QueueFooter(controller: controller),
        if (controller.busy)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
      ],
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 38,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text('Drop images here', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'or use the Add button above',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({
    super.key,
    required this.job,
    required this.selected,
    required this.onTap,
    required this.onRemove,
    required this.enabled,
  });

  final ImageJob job;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: ImageThumb(bytes: job.bytes, maxDim: 96),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _StatusLine(job: job),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusIcon(job: job),
                    SizedBox(
                      height: 22,
                      width: 22,
                      child: enabled
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Remove',
                              onPressed: onRemove,
                              icon: Icon(
                                Icons.close,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.job});

  final ImageJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (job.status == JobStatus.running) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: job.progress, minHeight: 3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(job.progress * 100).round()}%',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    if (job.status == JobStatus.done) {
      final saved = job.savedRatio;
      final q = job.solvedQuality;
      final parts = <String>[
        '${job.sourceSizeLabel} -> ${job.outputSizeLabel}',
        formatBytes(job.outputBytes),
        if (q != null) 'q$q',
        if (saved != null && saved > 0) '-${(saved * 100).round()}%',
      ];
      return Text(
        parts.join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 11),
      );
    }

    if (job.status == JobStatus.failed) {
      return Text(
        job.error ?? 'Failed',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
          fontSize: 11,
        ),
      );
    }

    return Text(
      '${job.sourceSizeLabel}  ·  ${formatBytes(job.inputBytes)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 11),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.job});

  final ImageJob job;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (job.status) {
      case JobStatus.done:
        return Icon(Icons.check_circle, size: 18, color: Colors.green.shade600);
      case JobStatus.failed:
        return Icon(Icons.error_outline, size: 18, color: scheme.error);
      case JobStatus.running:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.8),
        );
      case JobStatus.queued:
      case JobStatus.skipped:
        return Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant);
    }
  }
}

class _QueueFooter extends StatelessWidget {
  const _QueueFooter({required this.controller});

  final ResizeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = controller.overallSavedRatio;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          if (controller.doneCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 15,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${controller.doneCount} done',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (saved != null) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.savings_outlined,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(saved * 100).toStringAsFixed(1)}% smaller',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${formatBytes(controller.totalInputBytes)} -> ${formatBytes(controller.totalOutputBytes)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.busy || controller.pendingCount == 0
                      ? null
                      : controller.runBatch,
                  icon: const Icon(Icons.play_arrow_rounded, size: 19),
                  label: Text(
                    controller.pendingCount == 0
                        ? 'Process'
                        : 'Process ${controller.pendingCount}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.busy || controller.doneCount == 0
                      ? null
                      : () => _save(context),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Save all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final count = await controller.saveAll();
    messenger.showSnackBar(
      SnackBar(
        content: Text(count == 1 ? 'Saved 1 file' : 'Saved $count files'),
      ),
    );
  }
}
