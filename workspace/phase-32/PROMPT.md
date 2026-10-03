# phase-32 - Build, verify and publish the release APK and Windows executable

**Roadmap:** P6.3
**Depends on:** every other phase, hence the `.terminal` marker
**Terminal phase:** yes. This phase only runs once no ordinary phase is
outstanding, so it is always the last thing the loop does. If the audit later
appends new phases they push this one back to the end, automatically.

## Goal

Produce installable release artifacts from the current `main`, prove they are
what they claim to be, and attach them to a draft GitHub release with a version
derived from a tag rather than a hardcoded string.

## Why it matters

`.github/workflows/build.yml` already builds an APK and a Windows zip on every
push. Those are CI smoke artifacts. They are unsigned, unversioned, unnamed
after a release, and nobody is told they exist. This phase turns "CI produced
some files" into "here is a downloadable release you can install on a phone and
a zip you can run on Windows", and it verifies the artifacts rather than
assuming the build succeeded.

## Files

- `.github/workflows/release.yml`
- `pubspec.yaml`
- `android/app/build.gradle.kts`
- `docs/RELEASING.md`
- `scripts/verify-apk-permissions.sh`

## Approach

1. Read `pubspec.yaml` and get the current `version`. Report a warning in your
   notes if it is still `1.0.0+1` while more than thirty phases have landed,
   because a release that claims 1.0.0 forever is not a version. Do not
   unilaterally bump it; propose the value and record it in `docs/RELEASING.md`.

2. Write `scripts/verify-apk-permissions.sh`. It locates the newest `aapt2` under
   `$ANDROID_HOME/build-tools`, dumps the permission list of a given APK, prints
   it, and exits non-zero if `android.permission.INTERNET` or any other
   `uses-permission` appears. This is the product's central claim, so it belongs
   in a script anyone can run, not only inside a CI step.

3. Write `.github/workflows/release.yml`, triggered on `v*` tags and by
   `workflow_dispatch`:
   - `flutter build apk --release` for the universal APK
   - `flutter build apk --release --split-per-abi` for per-architecture APKs
   - `flutter build appbundle --release` for the Play Store bundle
   - `flutter build windows --release` on `windows-latest`, zipped
   - run `scripts/verify-apk-permissions.sh` against the universal APK and fail
     the job if it reports anything
   - verify the Windows zip actually contains `pixelforge.exe` and the plugin
     DLLs, not just that the build step exited zero
   - upload every artifact with the version in the filename
   - create or update a draft release with those assets and generated notes

4. Wire signing from the `RELEASE_KEYSTORE_B64` secret, the way phase 02 set it
   up. If phase 02 has not landed, say so in your notes and build unsigned rather
   than guessing at the Gradle wiring. Do not reintroduce a debug-signed release.

5. Extract the version from the tag: `VERSION=${GITHUB_REF_NAME#v}`. Write it
   into `pubspec.yaml` during the build so the artifact and the tag cannot
   disagree. Fail if the tag does not parse as `MAJOR.MINOR.PATCH`.

6. Write `docs/RELEASING.md`: how to tag, what the CI does, where the artifacts
   land, and how to verify a downloaded APK's permissions locally.

## Acceptance criteria

- [ ] Pushing a `v1.2.3` tag produces a universal APK, three split ABKs, an AAB
      and a Windows zip, all named with `1.2.3`
- [ ] `scripts/verify-apk-permissions.sh` exits non-zero on the real APK if any
      permission is present, and the release workflow fails because of it
- [ ] The script is runnable by hand: `bash scripts/verify-apk-permissions.sh <apk>`
- [ ] The Windows zip is checked to contain `pixelforge.exe`, and the workflow
      fails if it does not
- [ ] The APK's `versionName` equals the tag, verified with `aapt2 dump badging`
- [ ] A draft release exists with all assets attached and generated notes
- [ ] Signing uses the keystore from the secret, never the debug key. If phase 02
      has not landed, the workflow builds unsigned and says so in `docs/RELEASING.md`
- [ ] `flutter analyze`, `dart format --set-exit-if-changed` and `flutter test`
      are all clean, and this phase adds Dart code only if a test needs it
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Releasing is irreversible in one direction. Once an APK is published under a
version and users install it, that version can never be replaced. Consequences:

- Create the release as a **draft**. Never publish it. A human promotes it after
  checking the artifacts.
- Do not push a tag. Do not create a release without a human tag behind it.
- Version derivation must be strict. A tag like `v1.2` or `latest` must fail
  loudly rather than silently producing a build labelled `1.2.0`.

## Out of scope

Actually publishing the release, submitting to Google Play or the App Store,
handling review feedback, and building the iOS IPA. iOS needs a macOS runner and
a provisioning profile; note it as future work rather than attempting it.