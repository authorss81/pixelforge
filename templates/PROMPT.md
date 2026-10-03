# phase-NN — <short title>

**Roadmap:** <P-tier.item, e.g. P0.1>
**Depends on:** <phase-NN or nothing>

## Goal

<One paragraph. What is true when this phase is done that is not true now.>

## Why it matters

<The user-visible consequence. Data loss, a crash, a missing platform. If there
is no user-visible consequence, say so and reconsider the phase.>

## Files

<The files this phase is expected to touch. Touching anything else needs a
justification in your notes.>

- `lib/core/engine.dart`

## Approach

<Concrete steps. Name the actual functions and APIs. Where a package API is
involved, tell the reader to verify the signature in the pub cache rather than
trusting this prompt.>

1. <step>

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] <criterion>
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

<What could break that is not covered by the acceptance criteria. Where silence
would be worse than an error.>

## Out of scope

<The things a well-meaning agent would want to do here and must not.>