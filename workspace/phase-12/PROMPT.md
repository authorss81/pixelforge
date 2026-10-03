# phase-12 - Benchmark harness so performance claims are measurements

**Roadmap:** P1.5  
**Depends on:** phase-08

## Goal

A repeatable harness reports ms per photo and peak RSS at 12 MP, 24 MP and 48 MP for each resize mode and each output format. Every later performance phase quotes it.

## Why it matters

Every performance phase so far has been argued from intuition. Phases 04, 06, 08 and 09 all claim a speedup, and none of them can prove it. This harness is what turns those claims into facts.

## Files

Touching anything outside this list needs a justification in your notes.

- `benchmark/README.md`
- `test/benchmark_test.dart`
- `.github/workflows/build.yml`

## Approach

1. Generate synthetic sources at the three sizes with a deterministic pattern. A gradient compresses trivially and hides all the cost; use something with real high-frequency content so JPEG and WebP encoders do real work.
2. Report a table: size, mode, format, quality, ms per photo, output bytes, peak RSS. Use `dart:developer` `Timeline` or simply wall clock over several iterations with a median.
3. Run each measurement enough times to be meaningful and report the median plus the spread. A single run is noise.
4. Keep it in `test/` so `flutter test` can run it, but tag it so it is excluded from the normal fast test run.
5. Add it as a separate CI job that uploads the table as an artifact, so regressions are visible over time rather than rediscovered.
6. Publish the baseline table in `benchmark/README.md`. Every subsequent performance phase must update it in the same commit.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] The harness produces a table covering at least 12/24/48 MP, three modes and JPEG/PNG/WebP
- [ ] Results are medians over at least five iterations, with the spread reported
- [ ] The baseline table is committed and the CI job uploads a fresh one per run
- [ ] A later performance phase can quote real before-and-after numbers from it
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

This will be slow. Do not put it in the required-check path or `build.yml` will take twenty minutes and people will start skipping it.

## Out of scope

Comparing against other libraries or tools, and any attempt at cross-machine normalisation.

