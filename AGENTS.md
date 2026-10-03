# AGENTS.md

Rules for any agent operating on this repository. The ops loop reads this on
every phase.

## What this project is

PixelForge is a batch image resizer, compressor and format converter. Flutter
(Dart) UI over a pure-Dart image pipeline using `package:image`. Targets Windows,
Android, iOS and web from one codebase.

## Non-negotiables

These are enforced by tests and CI. If you cannot satisfy one, stop and report.
Do not work around it.

1. **Zero permissions.** `android/app/src/main/AndroidManifest.xml` must request
   no permissions at all. In particular never add `android.permission.INTERNET`.
   The release APK physically cannot open a socket, and that is the product's
   central claim. `test/privacy_test.dart` checks this and so does the `android`
   CI job, which dumps the built APK's permission list and fails on INTERNET.

2. **No network code.** No HTTP client, no socket, no analytics, no crash
   reporting service, no font or asset fetched at runtime. Every dependency must
   be pure-local. `test/privacy_test.dart` parses `pubspec.yaml` and fails if a
   banned networking package appears as a direct dependency.

3. **Never weaken a test.** Do not delete, skip, or loosen a test to make a run
   green. If a test encodes a wrong assumption, fix the test *and* say so
   explicitly in your phase notes. `test/privacy_test.dart` in particular must
   never be edited to relax an assertion.

4. **Never silently degrade.** This codebase has already shipped three silent
   losses and they are the reason these rules exist:
   - `package:image`'s `encodeWebP` is **lossless by default**, so a quality
     slider does nothing unless you pass `lossless: false`.
   - Animated GIF and animated WebP are **flattened to frame one** unless every
     frame is carried through the pipeline.
   - Alpha is **silently dropped** when converting to JPEG or BMP.

   If the pipeline cannot preserve something, fail loudly or report it. A user
   who loses data without being told is worse served than a user who gets an
   error.

5. **`flutter analyze` must report zero issues**, not zero errors. Warnings and
   lints are failures here. `dart format` must be a no-op.

6. **Stay in scope.** The phase prompt is the contract. Unrelated refactors,
   renames and drive-by cleanups belong in their own phase. A diff that touches
   files the prompt never mentioned needs a justification in your notes.

## Engineering notes you need

### Dart int/double

Dart only implicitly converts `int` to `double` for *literals*, never for
variables. `double f(int v)` cannot be called as `f(someInt)`. Change the
parameter to `num` instead. This has bitten the codebase twice.

### Verify the real API

Do not assume a package's API from memory. Read it:

```
~/.pub-cache/hosted/pub.dev/<package>-<version>/lib/
```

Three packages here have APIs that differ from their documentation or from older
versions:

- `file_picker` 13.x — `FilePicker` is an `abstract final class` with **static**
  methods. There is no `FilePicker.platform`, no `withData`, and no
  `allowMultiple`. Multi-select is implicit. `PlatformFile` has `readAsBytes()`,
  `lengthSync()` and an `extension` getter.
- `image` 4.x — `Image` has no `operator []`. Index pixels with `getPixel(x, y)`
  or iterate (`Image extends Iterable<Pixel>`). `Image` is iterable but `.zip`
  and `[]` are not available on it.
- `desktop_drop` 0.8.x — `DropItem extends XFile`, so it has `readAsBytes()` but
  **not** `lengthSync()`.

### Flutter Color

`Color.r`, `.g`, `.b`, `.a` are doubles in 0..1, not ints in 0..255. Use
`toARGB32()` to get an int. The bridge to the codec library is
`toCodecColor()` in `lib/core/engine.dart`.

### Performance model

`lib/core/engine.dart` is single-isolate and synchronous per image. The batch
loop in `lib/core/controller.dart` runs jobs **sequentially on the UI isolate**.
That is the known bottleneck the P1 phases exist to fix. When you touch the
pipeline:

- `copyResize` picks interpolation from the downscale ratio. `Interpolation.average`
  is the sweet spot for large reductions, `cubic` for large quality demands.
- `_solveToBudget` currently performs 7-8 **full-size** encodes. Phase 04 replaces
  this with a proxy-based solve. Do not add more encodes.
- Palette and indexed images (GIF with a colour table) silently drop to
  `Interpolation.nearest` inside `copyResize`. That is a known quality bug.

### Verification

```bash
flutter pub get
flutter analyze          # must be: No issues found!
dart format --output=none --set-exit-if-changed lib test
flutter test            # must be: All tests passed!
```

For visual changes, `flutter test` golden comparisons are the only automated
signal. There is no screenshot harness. If you change layout, say in your notes
that it needs a human eye.

## Phase mechanics

State lives in git, not in CI:

| Marker | Meaning |
|---|---|
| `workspace/<phase>/.done` | complete and verified |
| `workspace/<phase>/.blocked` | hit the attempt cap, needs a human |
| `workspace/<phase>/.deferred` | rate limited, retriable, not an attempt |
| `workspace/<phase>/.attempts` | real work attempts so far |
| `workspace/<phase>/.no_work` | agent exited 0 but changed nothing |
| `workspace/<phase>/.session` | opencode session id |
| `workspace/<phase>/.timeout` | optional runner timeout, default 90 min |
| `workspace/<phase>/.terminal` | runs only after every ordinary phase is `.done` |
| `workspace/.stop` | halts the entire pipeline |

Selection is two-pass: the lowest ordinary phase without `.done` or `.blocked`
wins; only when no ordinary phase remains does a `.terminal` phase run. That is
how the release build stays last while the audit can still append work, since
any new ordinary phase pushes the terminal phase back to the end. `phase-32` is
the terminal release build and its number is **reserved** — the audit starts its
generated phases at 33.

- After 3 failed attempts a phase is marked `.blocked`, skipped forever, and a
  GitHub issue is opened with the log tail. Fix the cause and delete the marker.
- Rate limits produce `.deferred` and never consume an attempt.
- The bot **pushes straight to `main`**. There are no pull requests, by design:
  a PR authored by `GITHUB_TOKEN` never receives CI, because GitHub suppresses
  the `pull_request` event for token-authored changes. Proven on this repo:
  `build.yml` went fully green on the exact PR head SHA and the PR still read
  `BLOCKED` with an empty `statusCheckRollup`.
- The gate is therefore the in-pipeline verification. `.done` is written only
  after `flutter analyze` and `flutter test` pass, and the review job verifies
  again after applying its fixes. `.done` on `main` is the proof.
- Phase work is committed and pushed **before** review runs, so a timeout in
  either job cannot destroy it.
- Branch protection still applies to the bot's pushes: linear history, no force
  push, no deletions, conversation resolution, and `enforce_admins`, so a
  deliberate local push is required for anything unusual.

## The self-audit phase

The last declared phase is an audit, not an implementation. It must:

1. Diff every `ROADMAP.md` checkbox against reality and write a truth table.
2. Run the benchmark harness and record **measured** numbers, never estimates.
3. Hunt for new instances of the known failure classes.
4. Re-verify the privacy invariants.
5. Write `workspace/<phase>/AUDIT_REPORT.md`.
6. **Generate new `workspace/phase-NN/PROMPT.md` files**, numbered from **33**,
   at most 8 of them, highest severity first. `phase-32` is reserved for the
   terminal release build and must never be emitted.

Because phase selection is "lowest ordinary phase without `.done`", newly
generated phases are picked up automatically and the loop continues without
intervention. Once the ordinary queue empties, the terminal release phase runs
and the loop ends.

The audit must never generate a phase that weakens the offline guarantee.