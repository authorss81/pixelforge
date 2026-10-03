# phase-06 - DCT-scaled decode so downscaling does not materialise 24 megapixels

**Roadmap:** P0.6  
**Depends on:** phase-04

## Goal

When the requested output is much smaller than the source, the decoder scales during the JPEG entropy decode instead of producing every source pixel first.

## Why it matters

A 24 MP JPEG decoded in full to shrink it to 400px wide allocates about 73 MB of RGBA and spends most of its time on pixels that get thrown away. libjpeg supports 1/8, 1/4, 1/2 and 1/1 scale factors on read for exactly this.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/engine.dart`
- `lib/core/resize_mode.dart`
- `test/resize_test.dart`

## Approach

1. Decide feasibility first, honestly. `package:image` 4.10.1 has its own `JpegDecoder`. Check whether it exposes DCT scaling. It most likely does not.
2. If it does not, the honest options are: an FFI binding to libjpeg-turbo with `scale_num/scale_denom`, or accepting the full decode. Do not fake it with a thumbnail hack and claim DCT scaling.
3. Report which path you took. If you cannot do real DCT scaling in pure Dart, write the limitation into `lib/core/engine.dart` as a documented constant and a follow-up phase, rather than pretending.
4. Regardless of outcome, add the precondition: compute the downscale ratio first, and skip intermediate RGBA allocation where a palette or 3-channel intermediate is sufficient.
5. Whichever path you take, verify peak memory with the phase 12 benchmark harness. If phase 12 does not exist yet, add a minimal `dart:io` memory measurement inside the test.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A test asserts peak decode allocation is below a stated ceiling for a 24 MP source resized to 400px
- [ ] The implementation is real DCT scaling, or the limitation is documented as unimplemented. A test must fail if a comment claims a capability the code does not have
- [ ] No path regresses the visual output beyond the interpolation change the phase already introduced
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

DCT scaling changes the effective resampling. Comparing before and after output at the same quality will show a difference. That is expected; quantify it rather than hiding it.

## Out of scope

Progressive JPEG scan optimisation, arithmetic coding, or trellis quantisation.

