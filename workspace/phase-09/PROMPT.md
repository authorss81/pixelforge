# phase-09 - Stream results to disk and bound peak memory

**Roadmap:** P1.2  
**Depends on:** phase-08

## Goal

Each finished image is written and its input bytes released immediately. Peak memory is bounded by concurrency, not by queue length, and an oversized batch is refused up front with an estimate.

## Why it matters

Right now every job holds its input bytes for the whole session and every output is retained until save. Fifty photos at 5 MB in and 2 MB out is around 350 MB resident. That is an OOM on a mid-range Android phone.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/job.dart`
- `lib/core/controller.dart`
- `lib/core/saver/saver_io.dart`
- `lib/core/saver/saver_web.dart`
- `lib/core/saver/saver_stub.dart`
- `test/resize_test.dart`

## Approach

1. `ImageJob` holds `Uint8List bytes`. Add a `releaseSource()` that nulls it out after the image is written, keeping only the preview thumbnail. The preview must survive this, so store the thumbnail as a separate small field.
2. Write each output as soon as its job completes rather than waiting for the save step. Make that configurable, because the current flow lets you tweak settings and re-run without having written anything.
3. Before starting a batch, estimate `sum(inputBytes) * concurrencyFactor` and compare against a memory budget. Refuse or chunk, and say which.
4. On web there is no filesystem write target, so outputs must stay in memory. Detect `dart.library.js_interop` and set the budget to 0 with an explanation rather than pretending streaming works.
5. Measure peak RSS before and after using the phase 12 harness, and put both numbers in your notes. If phase 12 is not done, add a minimal measurement to the test.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] Peak RSS for a 50-image batch is bounded by concurrency, and a test asserts a ceiling
- [ ] A job's source bytes are released after its output is written, asserted directly
- [ ] An oversized batch is refused before any work starts, with the estimate shown
- [ ] The web path is detected and does not claim to stream
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Releasing source bytes breaks re-running a phase without re-picking the files. Decide and document what happens when the user changes a setting after processing.

## Out of scope

Writing outputs to a zip during the batch, and cloud targets.

