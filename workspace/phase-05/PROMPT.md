# phase-05 - Selective metadata control instead of strip-everything

**Roadmap:** P0.5  
**Depends on:** nothing

## Goal

The user chooses which metadata survives: GPS, camera info, timestamps, or all of it, independently of the pixel data.

## Why it matters

The real need is usually 'strip the location but keep the camera and date'. Forcing a choice between everything and nothing makes people either leak GPS data or lose records they needed.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/engine.dart`
- `lib/core/settings.dart`
- `lib/ui/widgets/settings_view.dart`
- `test/resize_test.dart`

## Approach

1. The `image` package exposes EXIF as `ExifData` with `imageIfd`, `exifIfd`, `gpsIfd`, `interopIfd` and `thumbnailIfd`. Read `exif_data.dart` in the pub cache to confirm the API before coding.
2. Replace the single `stripMetadata` bool with a set of independent toggles. Keep `stripMetadata` working as a master switch for backwards compatibility with saved settings.
3. Apply the policy in `run()` where `work.exif = img.ExifData()` currently runs. Clear the chosen IFDs rather than the whole container so the survivor data is written out correctly.
4. Write a test that builds a JPEG with known EXIF values including GPS, strips GPS only, decodes the result and asserts the camera tag survived while the GPS tag did not.
5. Update the settings UI with a small checkbox group instead of one switch.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] Stripping GPS only leaves the camera make, model and timestamp intact, proven by a test that inspects the output bytes
- [ ] The master switch still works and maps onto all four toggles
- [ ] Saved settings from before this change load without crashing
- [ ] The settings UI exposes the toggles and the change is reachable by keyboard
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

The `image` package's EXIF writer is limited. Verify what it can actually re-inject with `injectJpgExif` before promising round-tripping. If a tag cannot survive, do not offer the toggle.

## Out of scope

XMP, IPTC, ICC profile handling, or a full metadata editor.

