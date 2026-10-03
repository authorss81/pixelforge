# phase-11 - Cancellation that actually interrupts a running encode

**Roadmap:** P1.4  
**Depends on:** phase-08

## Goal

Cancel stops the batch within one image, not after the current image finishes. Completed work is kept.

## Why it matters

The cancel button does not exist yet. When it does, an implementation that only checks a flag between images will still feel broken on a 50-photo batch of 24 MP files.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/controller.dart`
- `lib/core/engine.dart`
- `lib/core/job.dart`
- `lib/ui/widgets/queue_view.dart`
- `test/resize_test.dart`

## Approach

1. Use a cancellation token threaded through the pipeline. In an isolate, the correct mechanism is sending a message over the `SendPort` the isolate was given, not a shared mutable global.
2. Check for cancellation at the points where it is actually cheap: after decode, after resize, between frames, before encode. Do not check inside per-pixel loops; the overhead is not worth it.
3. An interrupted job ends as `JobStatus.skipped` with the reason recorded. Not `failed`, because nothing went wrong.
4. The UI shows partial results and a count of what was completed versus skipped. Losing completed work on cancel is its own bug.
5. Cancel must also be safe to press twice, and safe to press after the batch already finished.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] Cancelling a batch of 20 images stops within roughly one image of latency. A test measures the elapsed time from request to stop
- [ ] Completed outputs are retained and still saveable
- [ ] Interrupted jobs report `skipped` with a reason, not `failed`
- [ ] Double-cancelling is harmless, and cancelling a finished batch is a no-op
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

A cancel arriving during an encode cannot interrupt that encode, only the next one. Do not claim otherwise in the UI. Say 'finishing current image'.

## Out of scope

Pause and resume, and persisting a batch across app restarts.

