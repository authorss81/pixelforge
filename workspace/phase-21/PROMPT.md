# phase-21 - Draggable before/after divider

**Roadmap:** P3.2  
**Depends on:** phase-20

## Goal

A draggable divider compares original and result in one image, replacing the Before/After toggle.

## Why it matters

A toggle makes you remember what the original looked like. A split view shows both at once, which is how every real comparison tool works and how users already expect to compare.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/ui/widgets/preview.dart`
- `lib/ui/home_page.dart`
- `test/widget_test.dart` if it exists

## Approach

1. Stack the two images and clip the top one with a `ClipRect` driven by a draggable divider. Use a `GestureDetector` with `onHorizontalDragUpdate`.
2. Keep the toggle as an accessible fallback and honour screen-reader semantics. A pure-drag control is unusable with a screen reader.
3. Show a third state where both images sit side by side for narrow windows, where a split view has no room.
4. The divider must be keyboard reachable, with a visible focus indicator.
5. Zoom still has to work, and panning must not fight the divider drag. Decide which gesture wins where, and make it consistent.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] The divider drags and the clip follows it
- [ ] The control is reachable and operable by keyboard and by screen reader
- [ ] Panning the zoomed image and dragging the divider do not conflict
- [ ] The Before/After toggle still exists as an accessible alternative
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Gesture conflict with `InteractiveViewer` is the whole difficulty here. Test on a touch device or emulator, not just in a desktop widget test.

## Out of scope

A side-by-side diff view highlighting changed regions.

