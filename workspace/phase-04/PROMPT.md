# phase-04 - Solve the byte budget on a proxy, not on eight full encodes

**Roadmap:** P0.4  
**Depends on:** nothing

## Goal

Hitting a KB target costs two full-size encodes instead of seven to eight, with the same accuracy against the real budget.

## Why it matters

`_solveToBudget` in `lib/core/engine.dart` binary-searches quality, encoding the full-resolution image at each probe. A 24 MP JPEG costs roughly 400ms per encode, so a budget-targeted file spends three seconds to save work that one encode would do.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/engine.dart`
- `test/resize_test.dart`

## Approach

1. Keep the existing algorithm as the reference implementation and add a proxy path beside it, not in place of it, so the tests can compare them.
2. Build a proxy: downscale the already-resized image so its longest edge is about 512px, keeping the aspect ratio.
3. Binary-search quality on the proxy against `budget * (proxyPixels / fullPixels)`. Byte count scales close to linearly with pixel count, so this is a sound estimator, but verify it.
4. Encode the full image once at the solved quality. If it overshoots the real budget, drop quality by 5 and encode once more. Cap at two full encodes total.
5. Preserve the existing `metTarget: false` behaviour when even minimum quality cannot reach the budget. That honesty is load bearing.
6. Verify `encodeWebP` semantics in the pub cache first: it is lossless by default, so `quality` does nothing unless you pass `lossless: false`.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] The proxy path never performs more than two full-resolution encodes. Assert this with a counter, not by reading the code.
- [ ] Output quality is within 3% of the reference implementation's byte count
- [ ] An impossible budget still reports `metTarget: false`
- [ ] Both JPEG and WebP budgets are covered by tests
- [ ] A benchmark in the test output shows the encode count before and after
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

A 512px proxy mis-estimates highly compressible or highly detailed images. The single correcting encode is what absorbs that. Do not remove the correction step.

## Out of scope

Changing the user-facing quality slider, or adding per-image manual quality overrides.

