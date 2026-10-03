# phase-30 - Offline crash log and a CI smoke test

**Roadmap:** P6.2  
**Depends on:** phase-25

## Goal

Crashes are written to a file on device that the user can choose to share, and CI launches the built app and processes one image end to end.

## Why it matters

Crash reporting is normally a network call, which this project cannot have. Writing a local log the user opts into sharing is the honest version. And a build that compiles is not the same as a build that runs.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/diagnostics/crash_log.dart`
- `lib/ui/diagnostics_page.dart`
- `lib/main.dart`
- `test/smoke_test.dart`
- `.github/workflows/build.yml`

## Approach

1. Install global error handlers with `FlutterError.onError` and `PlatformDispatcher.instance.onError`. Append to a size-capped rotating file in the app's support directory.
2. Never write image data, file paths outside the app directory, or anything that identifies the user's photos. Redact paths and filenames. This is a privacy product; a crash log that leaks filenames undermines it.
3. Add a diagnostics page listing the log with a share action and a clear-delete button.
4. CI smoke test: launch the app on an emulator, feed it one bundled image, assert the output dimensions. Use `integration_test` rather than a widget test, since it needs a real device.
5. The smoke test asserts behaviour, not just that the app did not crash.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A thrown exception appears in the log file
- [ ] The log contains no user file paths or filenames. Add a test that fails if a redacted pattern ever appears
- [ ] The log is capped in size and rotates
- [ ] The CI smoke test launches the app, processes an image, and asserts the output dimensions
- [ ] `test/privacy_test.dart` unmodified and the CI permission check still passes
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

An emulator job is slow and flaky. If it becomes unreliable, people will disable it, and a disabled smoke test is worse than none because it looks like coverage.

## Out of scope

Symbolication, uploading logs automatically, and any remote diagnostics.

