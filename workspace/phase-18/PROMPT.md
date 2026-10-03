# phase-18 - Share-to-app and save-back-to-gallery

**Roadmap:** P2.5  
**Depends on:** phase-17

## Goal

A user can share an image from the gallery straight into PixelForge, and can send results back to Photos or the gallery.

## Why it matters

The natural mobile flow is share-in, process, share-out. Without it every job starts and ends with a trip through a file manager, which is the single biggest reason a phone user would abandon the app.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/main.dart`
- `lib/ui/home_page.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `test/privacy_test.dart`

## Approach

1. Register an `ACTION_SEND` intent filter with `image/*` on Android and a `CFBundleDocumentTypes` share entry on iOS.
2. Handle the incoming image as a content URI, not a path. On Android that means `ContentResolver.openInputStream`. The `ImageJob.path` field will be null, so verify `lib/core/engine.dart` decodes from bytes in that case.
3. Save-back on Android needs `MediaStore`, which requires `WRITE_EXTERNAL_STORAGE` on older APIs and nothing at all on scoped storage, API 29+. Handle both and be explicit about the version boundary.
4. On iOS, saving to Photos does need `NSPhotoLibraryAddUsageDescription`. Add it and only it. Note it in `test/privacy_test.dart` as the single justified iOS permission, with a comment explaining why.
5. Multiple images from one share: accept them, but cap at a documented number.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] Sharing one image into the app adds it to the queue
- [ ] Sharing several images adds all of them up to the documented cap
- [ ] Saving a result appears in the platform gallery
- [ ] `test/privacy_test.dart` is updated with an explicit, justified exception for the iOS add-only permission, and the Android manifest still has zero permissions
- [ ] The existing user-visible error for an unsupported share payload is clear
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Sharing into the app on iOS means handling `NSItemProvider`, which is asynchronous and can deliver HEIC. That depends on phase 15 working. If 15 is not done, say so and keep the path disabled.

## Out of scope

Share extensions, and receiving video.

