# phase-16 - HEIC and AVIF on desktop through libheif FFI

**Roadmap:** P2.3  
**Depends on:** phase-14

## Goal

Windows and Linux decode HEIC and AVIF through `libheif`, bundled per platform rather than assumed present on the system.

## Why it matters

A Windows user with an iPhone has a folder full of HEIC files and no way to batch them. Mobile is solved by phases 14 and 15 using the OS decoder; desktop has no such decoder, so it needs a real library.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/native/libheif.dart`
- `lib/core/native/libheif_bindings.dart`
- `windows/CMakeLists.txt` or the Flutter Windows CMake
- `lib/core/engine.dart`
- `test/privacy_test.dart`

## Approach

1. Use `dart:ffi`. This is the first phase that adds a native dependency, so it changes the project's build story. Be explicit about that in your notes.
2. Bundle libheif per platform and load it from next to the executable. Do NOT rely on it being installed on the system, and do not resolve it from a PATH lookup.
3. Check the signature of `heif_context_read_from_memory_without_copy` and the chroma conversion functions against the libheif version you bundle. Do not code against the latest header if you bundle an older library.
4. Use libheif's built-in `heif_context_get_primary_image_handle` plus a scaling API if the version supports it, otherwise scale after decode.
5. Make the whole thing fail closed. If the library cannot load, produce the existing clear error, never a crash or a silent no-op.
6. Add a Linux CI job so the FFI binding is compiled on every push. Windows alone will not catch a POSIX mistake.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A `.heic` decodes on both Windows and Linux in CI
- [ ] The bundled library loads from the app directory with no system install and no PATH lookup
- [ ] If the library fails to load, the error names libheif and the file. Assert that in a test
- [ ] The Web and iOS builds still compile. The FFI code must be conditionally imported
- [ ] `test/privacy_test.dart` unmodified and the CI permission check still passes
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

libheif is a large native dependency with its own transitive libraries, which inflates the Windows zip and complicates code signing. Measure the size delta and report it.

## Out of scope

HEIC encoding, HDR/10-bit handling, and grid images such as iPhone panoramas.

