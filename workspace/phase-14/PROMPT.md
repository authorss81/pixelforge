# phase-14 - HEIC and AVIF decoding on Android via the platform ImageDecoder

**Roadmap:** P2.1  
**Depends on:** phase-03

## Goal

A `.heic` file picked on Android decodes, resizes and re-encodes. No new permission, no bundled native library, no Rust FFI.

## Why it matters

This is the reason a phone user cannot use the app. Android's `ImageDecoder` has handled HEIF since API 28 and needs zero permissions, which means the cleanest possible fix also strengthens the privacy story.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/native/android_decoder.dart`
- `android/app/src/main/kotlin/.../MainActivity.kt`
- `lib/core/engine.dart`
- `test/privacy_test.dart`
- `.github/workflows/build.yml`

## Approach

1. Add a method channel. On the Kotlin side call `ImageDecoder` with `setTargetSize` so the platform decoder scales during decode, which also delivers a slice of phase 06 for free on Android.
2. Verify the ImageDecoder API against the compileSdk the project actually pins, not against the newest documentation.
3. Gate on `Build.VERSION.SDK_INT >= 28`. Below that, fall back to the Dart decoder and produce the existing clear error rather than a crash.
4. Guard the channel so the web and Windows builds still compile. Use a conditional import so `dart:io`-free platforms never see the Kotlin-facing code.
5. Add a JVM unit test using `Robolectric` or an instrumentation test. A pure Dart test cannot cover this, so make sure at least one CI job exercises it.
6. Re-run the CI permission check. `ImageDecoder` must not pull in a storage permission.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A `.heic` file decodes on an API 28+ emulator and produces correct output dimensions
- [ ] No new permission appears in the release manifest, and the CI permission check still passes
- [ ] API 27 and below produce the documented clear error, not a crash
- [ ] The Windows and web builds still compile with the channel in place
- [ ] `flutter analyze` and `flutter test` stay clean; `test/privacy_test.dart` unmodified
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

ImageDecoder is strict about some malformed HEIF files that libheif tolerates. A file that previously errored may now decode partially. That is an improvement, not a regression, but note it.

## Out of scope

HEIC encoding, HDR gain maps, 10-bit HEIF, and desktop HEIF support.

