# PixelForge

Batch image resizer, compressor and format converter for Windows, Android, iOS and the web.
Runs entirely offline: **the Android release manifest requests no permissions at all, so
the app has no way to open a socket.** That is enforced by a test, not just a promise.

Built with Flutter + a pure-Dart image pipeline (`package:image`). No Rust FFI, no native
codecs, no server.

## Why this exists

The open-source resizer landscape is thin where it matters:

| App | Stack | Gap |
|---|---|---|
| [ShareX / XerahS](https://github.com/ShareX/ShareX) | C# / Avalonia, 39.7k stars | The best feature set going, but Windows-only and screenshot-first |
| [ImageGlass](https://github.com/d2phap/ImageGlass) | C# | Windows viewer with batch ops |
| [nomacs](https://github.com/nomacs/nomacs) | C++ / Qt, 3.1k stars | Viewer, not a batch pipeline |
| [Converseen](https://github.com/Faster3ck/Converseen) | C++ / Qt | Batch processor, effectively unmaintained |
| [Squoosh](https://github.com/squoosh/squoosh) | JS / WASM | Offline but browser-only |
| Everything else on GitHub | assorted | Single-purpose scripts, unmaintained, or closed-source mobile apps |

Nothing open-source covered *batch resize + social/document presets + format conversion +
metadata control + offline* across **mobile and desktop** in one app. That is the gap.

## Features

**Sizing**
- 8 modes: fit inside box, pad into box, crop to box, stretch to box, set width, set height,
  scale by percent, keep original
- Centre-crop respects the target aspect ratio
- Upscale guard, on by default and optional
- Link/unlink width to height

**Presets** — 27 built in, grouped:
- Social: Instagram post/story, Facebook, X, YouTube thumbnail/banner, LinkedIn post/banner,
  Pinterest, TikTok, app icon
- Web: hero, retina 2x, card, thumbnail, favicon
- Documents: passport/ID, resume, 50 KB exam upload, 100 KB upload, A4 @ 300dpi, 4x6in @ 300dpi
- Optimize: max-compress WebP, 20 KB, email attachment, lossless PNG

**Output**
- JPEG, PNG, WebP, GIF, TIFF, BMP, or keep the source format
- Quality slider, or **solve quality per image** to land under a byte budget
  (binary search on the encoder; it tells you when the budget is impossible instead of lying)
- JPEG chroma 4:4:4 vs 4:2:0, WebP lossless and encode effort 0-6, PNG compression 0-9
- Strip EXIF/metadata — GPS, camera, timestamp

**Editing**
- Auto-levels when you have not touched brightness/contrast
- Brightness, contrast, saturation, exposure, hue, gamma, blend amount
- Grayscale, sepia, blur, sharpen
- Rotate 90°, flip H/V
- Text watermark: size, opacity, margin, five positions

**Batch**
- Drag and drop files *or folders* (walked 3 levels deep)
- Per-file thumbnails, live progress, before/after preview with pinch-zoom
- Filename templates: `{name} {w} {h} {origw} {origh} {index} {ext} {preset}`
- Collision handling, overwrite toggle, output folder picker

## Platform status

| Platform | Status |
|---|---|
| Windows | Built in CI |
| Android | Built in CI (APK + AAB) |
| Web | Supported |
| iOS / macOS / Linux | Sources present, not built in CI |

### Input formats

JPEG, PNG, WebP, GIF, TIFF, BMP, ICO, TGA, PSD, PNM, PVR, EXR.

**HEIC / HEIF / AVIF are not decoded in v1.** The pure-Dart codec set does not include them
and bundling `libheif` would mean shipping a per-platform native build, which is the thing
this project set out to avoid. The app tells you this explicitly instead of failing silently.
Converting to JPEG first works today. Adding native codecs is the main v2 item.

## Build it

```bash
flutter pub get
flutter test
flutter run -d windows      # or -d chrome, -d <android-device>
```

## Releases

Push a `v*` tag and the workflow builds a draft GitHub release with the APKs, the AAB and
a Windows zip. Builds also run on every push to `main`; artifacts are attached to the run.

## Autonomous development loop

The roadmap is not maintained by hand. An ops loop reads
[ROADMAP.md](ROADMAP.md), works one phase at a time, and writes its own next phases.

```
select-phase  picks the lowest workspace/phase-NN without .done or .blocked,
              reading markers through the GitHub API with no checkout
run-phase     installs Flutter and opencode, runs scripts/phase_runner.sh,
              then pushes the verified result straight to main
review        separate job, own budget, reviewer subagent, pushes corrections
              straight to main. Never invalidates a phase that already passed
retrigger     POSTs repository_dispatch back to itself, chaining the next phase
              in ~10s. tick.yml is a 10-minute cron safety net
```

Phase state lives in git as marker files, so any tick resumes with no external
state. See [AGENTS.md](AGENTS.md) for the full protocol.

### Why there are no pull requests

A PR authored by `GITHUB_TOKEN` never gets CI. GitHub suppresses the
`pull_request` event for changes made with the Actions token, as a recursion
guard, so no check-run ever attaches and `statusCheckRollup` stays empty.

This was verified on this repo rather than assumed. `build.yml` was dispatched
directly at the PR head and went fully green on the exact head SHA — `analyze +
test`, `android`, `windows` all `success` — while the PR still reported
`BLOCKED` with an empty rollup, and `gh pr merge` refused with *"the base branch
policy prohibits the merge"*. Any required status check is therefore permanently
unsatisfiable for a bot-authored PR.

That removes the entire point of a PR, which is the CI gate. So the bot pushes
to `main` directly and the gate is the in-pipeline verification instead:

1. `phase_runner.sh` runs `flutter analyze` and `flutter test`, and writes
   `workspace/<phase>/.done` **only if both pass**.
2. The review job pulls `main`, reviews the real committed tree, applies fixes,
   and verifies again.
3. `main` carrying a `.done` marker is the proof that the tree is green.

Phase work is pushed **before** review, so a timeout in either job cannot
destroy it. Branch protection still applies: linear history, no force push, no
deletions, conversation resolution, and `enforce_admins`. `build.yml` runs on
every push to `main` as the after-the-fact audit trail.

| Marker | Meaning |
|---|---|
| `workspace/<phase>/.done` | complete and verified |
| `workspace/<phase>/.blocked` | hit the attempt cap, skipped until a human removes it |
| `workspace/<phase>/.deferred` | rate limited; retried, and never costs an attempt |
| `workspace/<phase>/.no_work` | agent exited 0 but changed nothing |
| `workspace/<phase>/.timeout` | optional per-phase runner timeout, default 90 min |
| `workspace/<phase>/.terminal` | runs last, after every ordinary phase |
| `workspace/.stop` | halts the whole pipeline |

The 31 declared phases live in `workspace/phase-01` through `workspace/phase-31`.
`phase-31` is the self-audit: it measures reality with the benchmark harness,
checks every roadmap claim against the code, re-verifies the privacy invariants,
writes `AUDIT_REPORT.md`, and **generates new phase prompts starting at 33**.
Because selection is "lowest ordinary phase without `.done`", generated phases
are picked up automatically.

`phase-32` is marked `.terminal`. Terminal phases run only after every ordinary
phase is done, so the release build is always last — and if the audit appends
more work, the terminal phase is pushed back to the end rather than firing
prematurely. `phase-32` builds the release APK, split-ABI APKs, the Play bundle
and the Windows zip, verifies the APK really requests zero permissions, and
attaches everything to a **draft** release. Its number is reserved: the audit is
instructed to start at 33.

### Selection order

```
1. workspace/.stop present              -> halt
2. lowest .deferred, non-terminal       -> rate-limit retry
3. lowest ordinary phase, no .done      -> the next unit of work
4. lowest .terminal phase, no .done     -> only once step 3 is exhausted
5. nothing outstanding                  -> pipeline complete
```

### Running it

```bash
gh workflow run ops.yml                     # auto-select the next phase
gh workflow run ops.yml -f phase=phase-04    # force one
```

Requires the `OPENCODE_API_KEY` repository secret. The model chain starts at
`opencode/space-bunny-free` and falls back through 20 free tiers, advancing only
on model-level failures and never on a real work failure.

Stop the loop by creating an empty `workspace/.stop` file, or from the Actions UI.

### Branch protection

Applies to the bot's pushes too. A script rather than a workflow, because a
workflow's token cannot request the `administration` scope:

```bash
bash scripts/apply-branch-protection.sh authorss81/pixelforge
```

Required status checks are deliberately **not** set, for the reason above.

## Licence

MIT. See [LICENSE](LICENSE).
