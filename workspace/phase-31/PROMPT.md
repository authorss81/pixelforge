# phase-31 - Self-audit: measure reality, find what nobody thought of, and write the next phases

**Roadmap:** AUDIT  
**Depends on:** phase-30

## Goal

A written truth table of every roadmap claim against reality, a measured benchmark table, a ranked findings list, and up to eight new phases that the dispatcher will pick up automatically.

## Why it matters

The roadmap was written before any of it was built, so some of it will be wrong, some will already be obsolete, and some of the real problems are not on the list at all. This phase is how the plan corrects itself without a human in the loop.

## Files

Touching anything outside this list needs a justification in your notes.

- `workspace/phase-31/AUDIT_REPORT.md`
- `ROADMAP.md`
- `README.md`
- `workspace/phase-32..NN/PROMPT.md`
- `.github/workflows/branch-protection.yml`

## Approach

1. Use the `auditor` subagent, not the build agent. This phase writes rather than implements, and the audit prompt in `opencode.json` is scoped for exactly that.
2. Step one: read `ROADMAP.md` in full and check every checkbox against the code. Produce a truth table with three columns: claimed, actual, verdict. Include anything marked done that is not done, and anything not on the roadmap that is done.
3. Step two: run the phase 12 harness. Record measured numbers only. If the harness does not exist, say so and write it as the first new phase rather than guessing at numbers.
4. Step three: hunt for new instances of the failure classes that already bit this repo. Silent data loss, silently ignored settings, wrong API for the pinned package version, int and double coercion, unbounded memory. Use `AGENTS.md` as the checklist.
5. Step four: re-verify the privacy invariants. Zero permissions in the release manifest, no networking dependency, no socket client. If any has regressed, that is a severity 1 finding and it becomes phase 32.
6. Step five: name the competitive gaps from the table in `README.md`. Concrete features, not general directions.
7. Then write `workspace/phase-31/AUDIT_REPORT.md` with the truth table, the benchmark table, and findings ranked 1 to 4 with file and line.
8. Then generate `workspace/phase-32/PROMPT.md` onward, at most eight, numbered from the next free integer, highest severity first. Each must be independently shippable, must name its files, and must have acceptance criteria a test can check.
9. Update `ROADMAP.md` so its checkboxes match reality. A roadmap that lies is worse than no roadmap.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] `AUDIT_REPORT.md` contains a truth table covering every `ROADMAP.md` item
- [ ] Every benchmark number is measured. If the harness is missing, the report says so and no number is invented
- [ ] Findings are ranked 1 to 4 with file and line references
- [ ] Between one and eight new phase prompts are created, numbered from the next free integer, each independently shippable
- [ ] The privacy invariants are re-verified and the result is stated explicitly
- [ ] `ROADMAP.md` checkboxes now match reality
- [ ] The audit does not weaken `test/privacy_test.dart` and does not add a networking dependency
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

An audit that generates low-quality filler phases will burn free-tier model quota and produce churn. Cap it at eight and rank by severity. If it finds nothing, generating nothing is a valid and correct outcome.

## Out of scope

Implementing any finding. This phase writes; the generated phases implement. Do not fix a bug here even if you find one.

