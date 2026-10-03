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
run-phase     flutter + opencode, runs scripts/phase_runner.sh,
              pushes pf-bot/<phase> and opens a PR
review        separate job, own budget, reviewer subagent, never invalidates a
              phase that already passed
merge         gh pr merge --auto. main is branch-protected with the build.yml
              checks required, so only verified work lands
retrigger     POSTs repository_dispatch back to itself, chaining the next phase
              in ~10s. tick.yml is a 10-minute cron safety net
```

Phase state lives in git as marker files, so any tick resumes with no external
state. See [AGENTS.md](AGENTS.md) for the full protocol.

| Marker | Meaning |
|---|---|
| `workspace/<phase>/.done` | complete and verified |
| `workspace/<phase>/.blocked` | hit the attempt cap, skipped until a human removes it |
| `workspace/<phase>/.deferred` | rate limited; retried, and never costs an attempt |
| `workspace/<phase>/.no_work` | agent exited 0 but changed nothing |
| `workspace/<phase>/.timeout` | optional per-phase runner timeout, default 90 min |
| `workspace/.stop` | halts the whole pipeline |

The 31 declared phases live in `workspace/phase-01` through `workspace/phase-31`.
`phase-31` is the self-audit: it measures reality with the benchmark harness,
checks every roadmap claim against the code, re-verifies the privacy invariants,
writes `AUDIT_REPORT.md`, and **generates new phase prompts**. Because selection
is "lowest phase without `.done`", generated phases are picked up automatically.

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

`main` requires `analyze + test`, `android` and `windows` to be green, which is
what makes `gh pr merge --auto` wait instead of merging unverified work. This is
a script rather than a workflow, because a workflow's token cannot request the
`administration` scope:

```bash
bash scripts/apply-branch-protection.sh authorss81/pixelforge
```

## Licence

MIT. See [LICENSE](LICENSE).
