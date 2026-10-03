# phase-24 - Golden tests for the visual layer

**Roadmap:** P3.5  
**Depends on:** phase-23

## Goal

The queue, preview and settings panes have golden image tests, so a layout regression is caught in CI instead of by a user.

## Why it matters

PixelForge is a GUI app with no screenshot harness. llops-android solves this with Paparazzi for Compose; the Flutter equivalent is `matchesGoldenFile`. Without it, every layout change is unverifiable.

## Files

Touching anything outside this list needs a justification in your notes.

- `test/golden/`
- `test/widget_test.dart`
- `.github/workflows/build.yml`

## Approach

1. Add golden tests for the queue with items, the empty queue, the preview before and after, and the settings pane at three widths.
2. Set a fixed font size and disable OS text scaling so goldens are deterministic across machines.
3. Pin a Flutter version, since golden rendering is sensitive to the engine's rasteriser. The CI workflow already pins `FLUTTER_VERSION`; the goldens depend on it.
4. Commit the generated goldens. CI fails on a diff rather than regenerating them, which is the entire value.
5. Add a documented command for regenerating: `flutter test --update-goldens`.
6. Keep the goldens small. Full-resolution goldens bloat the repo and slow every run.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] Goldens exist for the queue, preview and settings at multiple widths
- [ ] CI fails on a golden diff and the failure message names the widget
- [ ] Goldens are deterministic across two consecutive runs
- [ ] The regeneration command is documented in the test file and in `docs/`
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Goldens are notoriously flaky across platforms. Generate them on Linux only, and run the golden job only on Linux, never on Windows or macOS runners.

## Out of scope

Per-platform goldens, and visual regression testing of the processed image output rather than the UI.

