# phase-22 - Multi-output UI

**Roadmap:** P3.3  
**Depends on:** phase-10

## Goal

The user can see, name and reorder every output a job produces, instead of a single result per file.

## Why it matters

Phase 10 makes multi-output possible in the engine. Without the UI, the capability is invisible and the throughput win is not actually delivered to anyone.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/ui/home_page.dart`
- `lib/ui/widgets/queue_view.dart`
- `lib/ui/widgets/preview.dart`
- `lib/ui/widgets/settings_view.dart`

## Approach

1. Let a job hold several outputs and show them as an expandable group in the queue. Collapsed, one row per photo. That keeps a 50-photo queue readable.
2. Reuse the before/after divider from phase 21 per output.
3. Extend the filename template with a `{preset}` token so outputs cannot collide. The token exists in `settings.dart` already; wire it into the collision path.
4. Presets must be removable and reorderable, and persist across restarts.
5. The single-preset path must feel unchanged. Someone who only ever uses one preset should not notice this feature exists.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A job with three presets shows three outputs, each savable under a distinct name
- [ ] Adding and removing a preset persists across an app restart
- [ ] Reordering changes the output filenames deterministically
- [ ] A single-preset run is visually and behaviourally unchanged
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

More UI state means more ways for the queue and the preview to disagree. Keep a single source of truth for which output is selected.

## Out of scope

A visual preset editor beyond adding and naming.

