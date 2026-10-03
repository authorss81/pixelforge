# phase-28 - Face-aware smart crop

**Roadmap:** P5.3  
**Depends on:** phase-06

## Goal

Crop mode centres on detected faces rather than on the geometric centre, so a group photo cropped to 1:1 keeps the people.

## Why it matters

Centre-cropping a portrait to a square cuts people's heads off. BinaryMark's face detection is the best feature in any commercial batch resizer, and it fits the offline story perfectly because the model runs locally.

## Files

Touching anything outside this list needs a justification in your notes.

- `assets/models/`
- `lib/core/detection/face_detector.dart`
- `lib/core/engine.dart`
- `lib/core/resize_mode.dart`
- `docs/FACE_MODEL.md`

## Approach

1. Pick a small ONNX face detector. Look for one in the single-digit-megabyte range, for example a MobileNet-based or SCRFD variant. Verify the licence permits redistribution and commercial use before shipping it. This is a real blocker, not a formality.
2. Run inference in an isolate via `dart:ffi` into ONNX Runtime, or through a platform channel. Do not add a dependency that would trip `test/privacy_test.dart`; if the chosen runtime is a networking-capable package, that is a problem.
3. The model runs on a downscaled copy, typically 640px. Detection does not need full resolution.
4. Change `computeCropPlan` to accept an optional focal point. With a face box, pick the crop window that maximises included faces, biased toward the source centre when nothing is detected. The existing behaviour must remain the default when detection is off.
5. Support multiple faces: score candidate windows by how many faces they contain, tie-broken by centring.
6. Make it toggleable, and clearly indicate when detection is unavailable, for example on an unsupported architecture.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A test with a synthetic face image crops to include the face, verified by pixel assertions
- [ ] With detection disabled the output is byte-identical to the current centre-crop, so existing behaviour is provably unchanged
- [ ] The model licence permits redistribution, and the licence text is committed alongside it
- [ ] Detection on a 24 MP image adds under 200ms, measured with the phase 12 harness
- [ ] The model file is not larger than about 10 MB and the size delta is reported
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

A false positive shifts the crop away from the subject, which is worse than a plain centre crop. Default the feature off and make detection confidence visible rather than silent.

## Out of scope

Object detection beyond faces, segmentation, and portrait retouching.

