# phase-07 - 16-bit, CMYK and multi-page TIFF

**Roadmap:** P0.7  
**Depends on:** nothing

## Goal

16-bit TIFFs do not silently lose precision, CMYK JPEGs are either handled or explicitly rejected, and multi-page TIFFs produce one output per page.

## Why it matters

A 16-bit TIFF silently truncated to 8 bits loses real precision in a way nobody notices until a print comes out wrong. Multi-page TIFFs currently collapse to a single page, which is data loss with the same shape as phase 01.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/engine.dart`
- `lib/core/settings.dart`
- `lib/ui/widgets/settings_view.dart`
- `test/resize_test.dart`

## Approach

1. Probe what `package:image` 4.10.1 actually supports. Read `tiff_decoder.dart`, `tiff_encoder.dart` and `format.dart` in the pub cache. Establish which of these are real today.
2. 16-bit: if the decoder exposes `Format.uint16`, keep the source bit depth through the pipeline instead of converting to uint8. If it does not, throw a clear error naming the file. Silent truncation is the one unacceptable outcome.
3. CMYK: Adobe JPEGs with a four-component APP14 marker. Either convert to RGB with a documented colour profile, or reject with an explicit message. Do not produce wrong colours.
4. Multi-page: TIFF pages live in `Image.frames`. Emit one output file per page, suffixed, following the same naming rules the rest of the app uses.
5. Wire each decision into the settings UI so the user can see what the pipeline will do before they run it.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A 16-bit TIFF either round-trips at 16-bit or fails with a message naming the format and the file
- [ ] A CMYK JPEG produces visibly correct colour or an explicit error. A test asserts one or the other, never silence
- [ ] A 3-page TIFF produces 3 output files with correct per-page dimensions
- [ ] Every rejection path uses `EngineError`, which is what the UI already knows how to display
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Rejection is a behaviour change. Someone whose 16-bit TIFFs currently 'work' will now get an error. That is the correct trade, but state it in your notes.

## Out of scope

Color management with ICC profiles, CMYK output, or 32-bit float TIFF.

