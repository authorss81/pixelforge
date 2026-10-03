# phase-29 - Store readiness

**Roadmap:** P6.1  
**Depends on:** phase-02

## Goal

Both stores have everything they require: real signing, a privacy policy, store metadata, and a build that installs from the artifact CI produces.

## Why it matters

Phase 02 makes the build signable. This makes it submittable. An unsigned, undocumented build does not ship.

## Files

Touching anything outside this list needs a justification in your notes.

- `docs/PRIVACY.md`
- `docs/STORE_LISTING.md`
- `.github/workflows/build.yml`
- `store/`

## Approach

1. Write `docs/PRIVACY.md` stating plainly what the app does not do. No network, no analytics, no permissions on Android, one photo-library-add permission on iOS and why. This is the app's strongest selling point, so make it a document a user would believe.
2. Verify the privacy manifest requirement on both platforms. Android needs a `data-safety` declaration in the store listing; iOS needs `PrivacyInfo.xcprivacy`. Neither is a code permission, but both are mandatory.
3. Write the store listing copy and capture real screenshots from the golden-test infrastructure or an emulator, not mockups.
4. Have `build.yml` produce a signed, versioned, installable artifact. Verify the artifact by installing it on a clean emulator, not just by checking the build succeeded.
5. Set a version scheme and wire it so the version in the store matches the commit.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] The signed artifact from CI installs and launches on a clean emulator
- [ ] `docs/PRIVACY.md` exists and every claim in it is checkable against the code
- [ ] The iOS privacy manifest is present and accurate
- [ ] Store listing copy exists with real screenshots
- [ ] The store version derives from the tag, not from a hardcoded string
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Signing material in CI is the highest-value secret in the project. A leaked keystore means an app that can never be updated in place. Use a GitHub environment secret, not a plain repository secret.

## Out of scope

Actually submitting to the stores, and handling review feedback.

