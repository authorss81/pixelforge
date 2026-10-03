# phase-08 - Isolate worker pool so the UI never blocks

**Roadmap:** P1.1  
**Depends on:** phase-04

## Goal

Decode, adjust and encode run in background isolates. The UI stays responsive and the progress bar keeps moving during a 50-photo batch.

## Why it matters

Today the whole pipeline runs synchronously on the UI isolate. A single 24 MP JPEG freezes the app for the best part of a second, and on Android that is an ANR risk. This is the most felt defect in the app.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/engine.dart`
- `lib/core/controller.dart`
- `lib/core/job.dart`
- `test/resize_test.dart`

## Approach

1. The top-level function passed to `compute()` must be a top-level or static function taking only primitives and sendable data. `ResizeSettings` holds a `Color` and a `WatermarkSettings`, which are sendable as plain values, but verify what actually crosses the isolate boundary in Dart 3.12 rather than assuming.
2. Cleanest structure: add `ResizeRequest`, a plain immutable data class holding everything the pipeline needs, plus a top-level `Future<EngineResponse> processIsolate(ResizeRequest)`. Both must be sendable. If `Color` proves not to be, carry `int` ARGB values instead.
3. Pool isolates rather than spawning one per image. `Isolate.run` per image is simple but pays spawn cost each time; measure whether that matters at these durations before building a real pool.
4. Throttle concurrency to `Platform.numberOfProcessors - 1` at minimum. More isolates than cores makes the batch slower, not faster.
5. Keep progress reporting working. An isolate cannot call `notifyListeners` directly; return progress through a `SendPort` or report only at phase boundaries and interpolate in the UI.
6. Never let a single failure kill the batch. An isolate error must become `JobStatus.failed` with the message attached, exactly like a main-isolate error does today.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A batch of 20 images keeps the UI interactive. Add a widget test or a benchmark that asserts frames are produced during processing
- [ ] Concurrency never exceeds the processor budget, asserted in a test
- [ ] An isolate-level exception marks that job failed and the batch continues
- [ ] Output bytes are byte-identical to the pre-phase single-isolate path for a fixed input. Add a test that pins this
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Isolates each carry their own heap. Ten isolates holding ten 24 MP images is worse than one holding them sequentially. This phase must not be merged together with phase 09 without measuring peak RSS.

## Out of scope

Moving work to native threads or platform channels, and any change to the output format.

