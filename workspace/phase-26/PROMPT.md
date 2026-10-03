# phase-26 - Images to PDF, and PDF to images

**Roadmap:** P5.1  
**Depends on:** nothing

## Goal

A selected set of images becomes one PDF at a chosen page size and DPI. A PDF becomes a set of images.

## Why it matters

Every competitor does images-to-PDF, and it is the most requested adjacent feature. It also gives the app a reason to exist for ID-photo and document workflows, not just resizing.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/pdf/writer.dart`
- `lib/core/pdf/reader.dart`
- `lib/core/engine.dart`
- `lib/ui/widgets/settings_view.dart`
- `test/resize_test.dart`

## Approach

1. Writing a PDF is not much code: a header, a page tree, one content stream per page, and the image XObject. JPEG can be embedded with DCTDecode directly, which means no re-encode and no quality loss. Do that rather than re-encoding to a raw bitmap.
2. For PNG, FlateDecode it. Verify the zlib output the `archive` package provides rather than assuming.
3. Reading PDFs is much harder. Be honest about scope: rasterising arbitrary PDF content is a large project. Start with images embedded in PDFs, which covers scans and exports from other tools. Say clearly what is unsupported.
4. Consider whether `syncfusion_flutter_pdf` or `pdf` would help, and note that both are large. Read their licences and their dependency footprint before adding one, given this project's constraints.
5. Page sizes in inches or millimetres at a chosen DPI, matching the existing preset vocabulary.
6. Ordering must be explicit and user-controlled. Sort by name by default.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] N images produce a valid PDF with N pages at the chosen size and DPI
- [ ] A JPEG embedded in a PDF is byte-identical to the source, proving no re-encode
- [ ] A test extracts or validates the page count of the produced PDF
- [ ] An unsupported PDF gives a clear message naming what is supported
- [ ] `test/privacy_test.dart` unmodified, or updated with a justification if a new dependency was added
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

A large PDF assembled in memory will OOM. Stream it or document the page ceiling. The phase 09 memory budget applies.

## Out of scope

PDF text extraction, forms, annotations, encryption, and vector graphics.

