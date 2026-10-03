# phase-19 - Background processing that survives the app being closed

**Roadmap:** P2.6  
**Depends on:** phase-11

## Goal

A long batch keeps running when the app is backgrounded, with a system notification showing progress and a cancel action.

## Why it matters

An image batch is measured in minutes. If the user switches apps and Android kills the process, everything is lost. This is the difference between a toy and something you can rely on.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/background/`
- `android/app/src/main/AndroidManifest.xml`
- `lib/ui/`
- `test/privacy_test.dart`

## Approach

1. On Android use a foreground service with a `notification` type. Android 14 requires declaring `foregroundServiceType`, so set it explicitly and document why.
2. The notification needs a `POST_NOTIFICATIONS` permission on API 33+. That is a real permission and it is the one exception this project may need. Add it, make it optional so the app works if denied, and record the justification in `test/privacy_test.dart`.
3. Android also restricts background starts. Starting a foreground service from the background needs a legitimate exemption. Verify the current rules rather than guessing.
4. On iOS background execution is time-limited and discretionary. Be honest: implement it as best-effort with `BGProcessingTask`, and tell the user when it will not work rather than pretending.
5. State what survives a process kill and what does not. Do not overclaim.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A batch continues after the app is backgrounded on Android, verified on an emulator
- [ ] The notification shows live progress and cancelling from it stops the batch
- [ ] The app functions normally with notifications denied
- [ ] `test/privacy_test.dart` documents exactly which permission was added and why, and nothing else was
- [ ] The iOS path degrades visibly rather than silently
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Foreground services drain battery and are user-visible. This is a real cost, not free. Do not start one for a batch that finishes in under ten seconds.

## Out of scope

Scheduled recurring processing, and processing in the cloud.

