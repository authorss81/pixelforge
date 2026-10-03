# phase-27 - ZIP bundle output

**Roadmap:** P5.2  
**Depends on:** phase-09

## Goal

Output can be written as a single zip instead of a folder full of loose files, with optional folder structure preserved.

## Why it matters

Loose files in a directory is the wrong shape for delivering a batch. A zip is what people actually want to send or upload.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/saver/archive_writer.dart`
- `lib/core/saver/saver_io.dart`
- `lib/core/saver/saver_web.dart`
- `lib/core/saver/saver_stub.dart`
- `test/resize_test.dart`

## Approach

1. `archive` is already a transitive dependency, brought in by `file_picker`. Verify it is available directly or add it explicitly, and check what it pulls in against `test/privacy_test.dart`.
2. Stream into the zip as each output completes rather than buffering everything. Phase 09 makes this possible.
3. Preserve relative paths when the source came from a folder drop, so the zip mirrors the input tree. This is the difference between useful and annoying.
4. Write a central directory at the end. A zip missing it is unopenable, and this is the easiest thing to get wrong.
5. On web, produce one zip download instead of N downloads. That alone justifies the feature on mobile web.
6. Compression level matters: JPEG does not compress, PNG barely does. Do not waste seconds deflating incompressible data.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] A produced zip opens and contains every expected file at the expected path
- [ ] The zip is written incrementally, not buffered fully in memory. Assert memory does not scale with batch size
- [ ] Folder structure is preserved when the input had one
- [ ] Web produces exactly one download
- [ ] A zip of incompressible data does not take meaningfully longer than a zip of compressible data
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Interleaving reads, writes and zip assembly complicates phase 09's streaming. Do this after 09 lands, not in parallel.

## Out of scope

Password-protected zips, split archives, and configurable compression per format.

