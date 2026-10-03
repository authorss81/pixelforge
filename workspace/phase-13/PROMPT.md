# phase-13 - Correct resampling for palette and indexed images

**Roadmap:** P1.6  
**Depends on:** nothing

## Goal

Resizing a palette or indexed GIF no longer silently degrades to nearest-neighbour. Indexed images either take a proper path or are converted with the user informed.

## Why it matters

`copyResize` in the `image` package force-downgrades interpolation to `Interpolation.nearest` when `src.hasPalette`. The user gets a jagged result with no explanation. AGENTS.md already documents this as a known bug.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/engine.dart`
- `test/resize_test.dart`

## Approach

1. Detect `work.hasPalette` before the resize. Convert to a direct-colour representation with `img.convert(numChannels: 4)` and resize that properly.
2. Quantise back to a palette only if the output format requires it, and only when the colour count permits. Otherwise keep direct colour.
3. Quantisation visibly changes colour. Expose it rather than hiding it, and note it in your summary.
4. Measure the quality difference on a real indexed GIF and report it.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A resized indexed GIF no longer produces nearest-neighbour artefacts, proven by a test comparing against the direct-colour path
- [ ] Any quantisation is disclosed in the phase notes with a measured colour delta
- [ ] Palette JPEG, palette PNG and indexed GIF inputs are all covered
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Direct colour output is larger than palettised. For a GIF destined for the web this may be the wrong trade. Expose it as a setting if the size difference is significant.

## Out of scope

A new quantisation algorithm, median-cut improvements, or dithering.

