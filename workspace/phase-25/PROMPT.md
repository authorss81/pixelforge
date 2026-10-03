# phase-25 - Onboarding, auto-save, real errors, keyboard shortcuts

**Roadmap:** P4.1  
**Depends on:** nothing

## Goal

A first run explains the app in three screens. Settings save automatically. Errors name the actual cause. Desktop has keyboard shortcuts.

## Why it matters

These are the small frictions that make an app feel unfinished. Settings needing a manual save button is the clearest example: it implies unsaved work that never exists.

## Files

Touching anything outside this list needs a justification in your notes.

- `lib/core/settings.dart`
- `lib/ui/home_page.dart`
- `lib/ui/widgets/settings_view.dart`
- `lib/core/engine.dart`
- `lib/ui/onboarding.dart`

## Approach

1. Settings: debounce saves at roughly 400ms and drop the save button. Show a brief confirmation instead so the user knows it persisted.
2. Errors: today every decode failure produces one generic string. Split `EngineError` into distinct cases: unsupported container, corrupt data, native codec missing, out of memory, and permission denied. Each needs its own message naming what the user can do about it.
3. Onboarding: three screens. What the app does. That it is offline and why that matters. Pick a preset and go. Dismissible, and never shown again once completed.
4. Keyboard shortcuts on desktop: add files, process, save, delete selection, toggle preview, and focus search. Show them in a shortcuts dialog.
5. Apply the real fix for every unimplemented input format the error paths reference. A user who picks a `.heic` on Windows should be told libheif is missing, not that the file is corrupt.

## Acceptance criteria

Each must be checkable by a test or by `flutter analyze`.

- [ ] Settings persist without any explicit save action, and a test proves debounced persistence
- [ ] Each `EngineError` case produces a distinct, actionable message, asserted by a test per case
- [ ] Onboarding appears once and never again, proven by a test
- [ ] Every keyboard shortcut is listed in a dialog and works. A widget test fires each one
- [ ] Picking an unsupported format names that format and the reason
- [ ] A new test in `test/` fails before this change and passes after
- [ ] `flutter analyze` reports `No issues found!`
- [ ] `dart format --output=none --set-exit-if-changed lib test` is a no-op
- [ ] `flutter test` reports `All tests passed!`
- [ ] `test/privacy_test.dart` is unmodified

## Regression risk

Auto-save means a settings change lands on disk without the user asking. If `loadFrom` ever throws, the app must start with defaults rather than failing to start.

## Out of scope

A settings search field, which is separate and lower value.

