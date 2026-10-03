# phase-17 - Photo Picker so mobile users never grant library access

**Roadmap:** P2.4  
**Depends on:** phase-14

## Goal

On mobile the user picks photos through the system picker. The app receives only what the user selected and requests no library permission.

## Why it matters

Going through a generic file dialog on a phone is a poor experience, and asking for full library access is a privacy problem. The system photo picker solves both and is permission-free on Android.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/native/photo_picker_android.dart`
- `lib/core/native/photo_picker_ios.dart`
- `lib/core/picker.dart`
- `android/app/src/main/AndroidManifest.xml`
- `test/privacy_test.dart`

## Approach

1. On Android use `ActivityResultContracts.PickMultipleVisualMedia`. It requires zero permissions. Verify the exact contract name and the `PickVisualMediaRequest` API against the compileSdk, not against documentation.
2. On iOS use `PHPickerViewController`. It returns only the selected assets and needs no `NSPhotoLibraryUsageDescription` for picking.
3. Update `SourcePicker` to prefer the system picker on mobile and keep `FilePicker` for desktop.
4. Handle the large-image case properly. A modern phone photo can be 50 MB. The system picker can hand back a full-resolution URI that OOMs on decode. Use the picker's downscale option, or `ImageDecoder`'s target size.
5. Do NOT add `READ_MEDIA_IMAGES` to make this easier. That defeats the entire point and `test/privacy_test.dart` will catch it.
6. Write a test asserting the manifest still has zero permissions after this change. That test is the whole reason this phase is safe.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A photo is picked on Android with no permission in the manifest, asserted by test
- [ ] A photo is picked on iOS with no `NSPhotoLibraryUsageDescription` for picking
- [ ] A 50 MP photo does not OOM, because the picker or decoder is given a target size
- [ ] The desktop file-picker path is unchanged and still tested
- [ ] CI on `macos-latest` and an Android emulator job both exercise the picker
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

The system picker returns a content URI on Android, not a file path. `PlatformFile.path` assumptions in `ImageJob.path` break. Audit every use of `path`.

## Out of scope

Camera capture, and saving back to the library, which is phase 18.

