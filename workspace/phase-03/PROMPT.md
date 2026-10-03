# phase-03 - Add the missing iOS target

**Roadmap:** P0.3  
**Depends on:** nothing

## Goal

An `ios/` target exists, builds, and passes the same tests. The README's claim of iOS support becomes true.

## Why it matters

The README lists iOS as supported and there is no iOS directory. Worse, HEIC is the dominant iPhone photo format and phase 15 depends on this target existing.

## Files

Touching anything outside this list needs a justification in your notes.

- `ios/` (generated)
- `pubspec.yaml`
- `README.md`

## Approach

1. Run `flutter create --platforms=ios .` to generate the target. Do not hand-write the Xcode project.
2. Set the display name to PixelForge and the bundle identifier to something sane and documented.
3. `file_picker` 13.x needs iOS entitlements for photo library access. Add only what the phase 17 Photo Picker work needs, and note it here.
4. Do NOT add a networking entitlement. There must be no `com.apple.security.network.client` anywhere.
5. Build with `flutter build ios --no-codesign` in CI to prove it compiles without a provisioning profile.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] `flutter build ios --no-codesign` succeeds in CI on macOS
- [ ] `flutter build ios --no-codesign` is added as a job in `build.yml` on `macos-latest`
- [ ] The iOS bundle contains no networking entitlement
- [ ] The README's platform table matches what actually builds
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Adding an iOS job to CI costs macOS runner minutes, which are billed at 10x Linux. Run it only on push to main, not on every pull request.

## Out of scope

App Store signing, TestFlight, or any App Store Connect configuration.

