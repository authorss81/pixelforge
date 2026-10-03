# phase-10 - Multi-output: one decode, N presets

**Roadmap:** P1.3  
**Depends on:** phase-08

## Goal

The user queues several presets at once and one decode feeds all of them. A single photo can export 1080x1080, 1920x1080 and a 50 KB variant in one pass.

## Why it matters

The current design forces one preset per run, so getting three sizes out of a folder means three full passes and three decodes. This is the single largest throughput win available and it is how real batch tools behave.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/engine.dart`
- `lib/core/controller.dart`
- `lib/core/settings.dart`
- `lib/ui/widgets/settings_view.dart`
- `lib/ui/home_page.dart`
- `test/resize_test.dart`

## Approach

1. Split `ResizeEngine.run` into `decodeOnce(bytes) -> DecodedSource` and `renderTo(source, settings) -> EngineResult`. Everything expensive, which is decode, happens once. Render stays per-preset.
2. This split is also what phases 04, 06 and 08 need. If they have already restructured it, adapt rather than restructure again.
3. A single `ImageJob` becomes one job producing N results. Model the outputs as a list on the job rather than N jobs, so the queue does not show 50 rows for 50 photos.
4. One quality solve per output, each against its own byte budget. Do not share a solved quality across presets; a 20 KB thumbnail and a 2 MB hero need different values.
5. Output filenames must not collide across presets. Extend the template with a `{preset}` token, which already exists in `settings.dart` but is not yet in the collision path.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] Three presets from one decode performs exactly one decode. Assert the count.
- [ ] Each output lands under its own byte budget, independently
- [ ] Filenames across presets never collide, and a test proves it
- [ ] Single-preset behaviour is unchanged and covered by the existing tests
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Holding the decoded source across N renders keeps a full-resolution image resident for longer. Interacts with phase 09. Measure rather than assume.

## Out of scope

A visual multi-output queue UI beyond what is needed to select and name the outputs.

