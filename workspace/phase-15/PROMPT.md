# phase-15 - HEIC decoding on iOS via ImageIO

**Roadmap:** P2.2  
**Depends on:** phase-14

## Goal

The iPhone case works. `.heic` and `.heif` decode on iOS through `ImageIO`, with no added entitlement beyond what phase 17 already needs.

## Why it matters

HEIC is the default iPhone photo format. Without this the app is unusable for the exact audience it most needs to serve.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/native/ios_decoder.dart`
- `ios/Runner/AppDelegate.swift` or the equivalent
- `lib/core/engine.dart`
- `test/privacy_test.dart`

## Approach

1. Use `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize`. It performs the downscale during decode, so this also covers the iOS half of phase 06.
2. Respect `kCGImageSourceCreateThumbnailWithTransform` so EXIF orientation is handled by the platform rather than by our own bake step. Getting this wrong produces sideways output on exactly the photos people care most about.
3. Reuse the same channel shape as phase 14 so the Dart side has one API.
4. Add an iOS test target run on `macos-latest` in CI. There is no way to test this on Linux, so this job must be macOS or the phase is unverified.
5. Confirm no `App Transport Security` exception or network entitlement crept in.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] An iPhone HEIC decodes and resizes with correct orientation
- [ ] The CI macOS job exercises this path, not just compiles it
- [ ] No new entitlement beyond photo library access
- [ ] The Dart decoder remains the fallback and its error path is still covered
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

iOS returns premultiplied alpha with its own colour space handling. Round-tripping to JPEG can shift colours slightly. Verify rather than assume.

## Out of scope

HEIC encoding, Live Photos, and portrait-mode depth data.

