# phase-01 - Preserve animated GIF and WebP instead of flattening them

**Roadmap:** P0.1  
**Depends on:** nothing

## Goal

An animated GIF or animated WebP processed by PixelForge stays animated. Every frame is decoded, resized, adjusted and re-encoded, with per-frame durations preserved.

## Why it matters

This is silent data loss. A user who exports a frame-by-frame avatar animation gets a still image and is never told. It is also the single most likely reason someone would report the app as broken without being able to say why.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/engine.dart`
- `lib/core/settings.dart`
- `lib/ui/widgets/settings_view.dart`
- `test/resize_test.dart`

Note: an earlier run of this phase correctly implemented the engine and settings
work but had no UI switch for `preserveAnimation`, because the file list omitted
`lib/ui/widgets/settings_view.dart`. It is now included. The engine work from that
run was sound and is on `pf-bot/wip/phase-01` if you want to compare approaches.

## Approach

1. `img.decodeImage` already returns an `Image` whose `frames` list holds every frame. Today `run()` operates on frame 0 only and calls `encodeGif(im, singleFrame: true)`.
2. Split the pipeline into a per-frame transform: `Image applyToFrame(img.Image frame, ResizeSettings s, TargetSize target)`. Geometry that depends on aspect ratio must be computed from frame 0 once, then reused for every frame, so all frames stay the same size.
3. Rebuild the animated result with `result.addFrame(transformedFrame)` and set `frameDuration` from the source frame.
4. Encode with `singleFrame: false`. Check the `image` 4.10.1 signatures in the pub cache before coding; the encoder refuses a frame larger than the canvas.
5. Add a setting: `preserveAnimation` (default true), so a user can deliberately flatten. When false, keep current behaviour.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] An animated GIF round-trips with the same frame count
- [ ] An animated WebP round-trips with the same frame count
- [ ] Each frame is resized to the target geometry, not just the first
- [ ] Setting `preserveAnimation: false` flattens to frame one, and a test proves both paths
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Per-frame resize multiplies encode time by the frame count. Encode cost, not decode cost, will dominate. Note the slowdown in your summary.

## Out of scope

Changing frame durations, dropping frames to hit a byte budget, or adding GIF/WebP animation creation from stills.

