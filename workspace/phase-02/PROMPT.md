# phase-02 - Real release signing instead of the debug key

**Roadmap:** P0.2  
**Depends on:** nothing

## Goal

A release build is signed with a real, documented keystore driven by `key.properties`, and it fails loudly when that file is absent. CI signs from a secret.

## Why it matters

`android/app/build.gradle.kts` currently points `signingConfigs.release` at `signingConfigs.debug`. Play Store rejects that outright, and a debug-signed release cannot be updated in place later without uninstalling.

## Files

Touching anything outside this list needs a justification in your notes.

- `android/app/build.gradle.kts`
- `android/key.properties.example`
- `docs/SIGNING.md`
- `.github/workflows/build.yml`
- `.gitignore`

## Approach

1. Add `android/key.properties.example` with the five fields and no real values. Confirm `key.properties` and `*.jks` stay in `.gitignore`; they already do.
2. In `build.gradle.kts`, load `key.properties` if present and build a real `signingConfigs.create("release")`. When the file is absent, do not silently fall back to debug. Throw a GradleException with a message pointing at `docs/SIGNING.md`.
3. Wire the `release` buildType to it only when available, and add a Gradle task `verifyReleaseSigning` that fails if a release build is requested without signing material.
4. Document key generation with `keytool`, and the base64 secret workflow: `base64 -w0 release.jks` stored as `RELEASE_KEYSTORE_B64`.
5. In `build.yml`, reconstruct the keystore from the secret into `$RUNNER_TEMP` and pass the passwords to Gradle as `ORG_GRADLE_PROJECT_*` properties. Never echo them.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] `./gradlew :app:verifyReleaseSigning` fails with a helpful message when `key.properties` is missing
- [ ] `./gradlew :app:verifyReleaseSigning` succeeds when it is present
- [ ] `key.properties`, `*.jks` and `*.keystore` are all in `.gitignore`
- [ ] A signed release APK builds in CI and its signature verifies with `apksigner verify`
- [ ] No secret value appears in any workflow log
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Making signing mandatory will break every local `flutter run --release`. That is intended, but make the error message obvious enough that nobody is stuck.

## Out of scope

Play Store upload, Play App Signing, or key rotation policy.

