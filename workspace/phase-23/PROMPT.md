# phase-23 - Design tokens, accessibility pass and RTL

**Roadmap:** P3.4  
**Depends on:** nothing

## Goal

Spacing, type and elevation come from a token scale. Every control is reachable and labelled by keyboard and screen reader. The layout mirrors correctly in RTL.

## Why it matters

Spacing is currently ad-hoc across `lib/ui`, which is why nothing quite lines up. Accessibility and RTL are not polish, they are correctness, and both get worse as features are added rather than better.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/ui/theme.dart`
- `lib/ui/widgets/`
- `lib/main.dart`
- `pubspec.yaml`
- `test/widget_test.dart`

## Approach

1. Define a spacing scale, a type scale and a radius scale as constants in `theme.dart`. Replace every magic number. This is mechanical and large; do it in one pass so it does not linger as half-done work.
2. Add `flutter_localizations` and `intl`, set `supportedLocales`, and make every user-visible string come from a localisation delegate. The strings are already centralised, so this is wiring rather than a rewrite.
3. Wrap the run of tests so far into a widget test file. Semantics on every icon-only button. Logical focus order. Visible focus rings. Test at 200% text scale and confirm nothing clips.
4. Audit for RTL: replace directional `EdgeInsets.only(left:, right:)` with `EdgeInsetsDirectional`, and check every icon that implies a direction.
5. Check contrast in both light and dark themes against WCAG AA.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] `flutter analyze` finds no magic-number lint for spacing
- [ ] Every interactive widget has a semantic label. Add a test that walks the tree and fails on an unlabelled `IconButton`
- [ ] The UI is usable at 200% text scale with no clipped or overlapping text
- [ ] The app mirrors correctly under an RTL locale, tested with `Directionality`
- [ ] Light and dark themes both pass an AA contrast check
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Converting to `EdgeInsetsDirectional` changes left/right padding everywhere and will visibly shift the layout in LTR too. Expect to fix a few by eye.

## Out of scope

A full redesign, custom typography, and translating the strings themselves.

