# PixelForge roadmap

Everything that would take this from a working v1 to a world-class image
resizer. Ordered by what actually blocks users, not by what is fun to build.

**This file is machine-maintained.** Every item below is mapped to an
autonomous phase in `workspace/phase-NN/PROMPT.md`, and `phase-31` audits this
document against the code and rewrites it. Do not hand-edit a checkbox to mark
work done; let the audit do it, or the loop loses its ground truth.

| Phase | Tier | Item |
|---|---|---|
| 01 | P0 | Animated GIF/WebP preservation |
| 02 | P0 | Real release signing |
| 03 | P0 | Missing iOS target |
| 04 | P0 | Byte-budget solver on a proxy |
| 05 | P0 | Selective EXIF control |
| 06 | P0 | DCT-scaled decode |
| 07 | P0 | 16-bit, CMYK, TIFF pages |
| 08 | P1 | Isolate worker pool |
| 09 | P1 | Streaming results, bounded memory |
| 10 | P1 | Multi-output from one decode |
| 11 | P1 | Real cancellation |
| 12 | P1 | Benchmark harness |
| 13 | P1 | Indexed-GIF resampling |
| 14 | P2 | HEIC/AVIF on Android |
| 15 | P2 | HEIC on iOS |
| 16 | P2 | HEIC/AVIF on desktop via libheif |
| 17 | P2 | Photo Picker |
| 18 | P2 | Share intent, save to gallery |
| 19 | P2 | Background processing |
| 20 | P3 | Live preview |
| 21 | P3 | Before/after drag divider |
| 22 | P3 | Multi-output UI |
| 23 | P3 | Design tokens, a11y, RTL |
| 24 | P3 | Golden tests |
| 25 | P4 | Onboarding, auto-save, errors, shortcuts |
| 26 | P5 | PDF in/out |
| 27 | P5 | ZIP bundle output |
| 28 | P5 | Face-aware smart crop |
| 29 | P6 | Store readiness |
| 30 | P6 | Offline crash log, CI smoke test |
| 31 | AUDIT | Self-audit, generates phases 32+ |

Status legend: `[ ]` todo · `[~]` in progress · `[x]` done

Current state: analyzer clean, 30 tests green, CI green for analyze/test,
Android and Windows. Known gaps in v1 are listed in the README.

---

## P0 — Correctness bugs (lose data, or block release)

- [ ] **Animated GIF/WebP are flattened to frame 1** — silent data loss. Carry every
      frame through decode → resize → encode, resize per frame, encode with
      `singleFrame: false`. Affects `ResizeEngine._encode`.
- [ ] **Release builds are debug-signed** — `android/app/build.gradle.kts` points
      `signingConfigs.release` at `signingConfigs.debug`. Play Store rejects this.
      Generate a real keystore, wire `key.properties` (already gitignored),
      document regeneration.
- [ ] **No iOS target exists** — the README claims iOS support. Run
      `flutter create --platforms=ios .`, then build and test it.
- [ ] **The byte-budget solver performs 7–8 full-size encodes per image** —
      `_solveToBudget` in `lib/core/engine.dart`. Solve quality on a ~512px proxy
      first, then do one full encode at the solved quality, verify once and
      correct at most twice. Expect a ~5x speedup on budget-targeted runs.
- [ ] **No selective metadata control** — all-or-nothing strip. Add per-tag
      toggles. "Strip GPS but keep camera and timestamp" is the common real need,
      not "strip everything".
- [ ] **Full decode before downscale** — a 24 MP JPEG fully materialises in order
      to shrink it to 400 px wide. Use native DCT-scaled decode on read
      (libjpeg supports 1/8, 1/4, 1/2 scale factors).
- [ ] **No 16-bit, CMYK, or multi-page TIFF handling** — add 16-bit paths and
      preserve TIFF pages.

## P1 — Performance and memory

- [ ] Isolate worker pool (`compute()`) sized to core count. Decode → adjust →
      encode must never touch the UI thread.
- [ ] Stream results to disk and release input bytes as soon as an image is
      written. Retain only a small preview thumbnail per job.
- [ ] Memory budget guard — estimate the batch up front, refuse or chunk when it
      cannot fit, and show the estimate.
- [ ] **Multi-output from a single decode** — export one photo to N presets
      without re-decoding it. Biggest throughput win available.
- [ ] Cancellation that genuinely interrupts a running encode.
- [ ] Real throughput reporting (MB/s), not phase-based fake percentages.
- [ ] Reuse decoded state across preset changes so re-running is instant.
- [ ] Palette / indexed-GIF resize path — `copyResize` silently downgrades these
      to nearest-neighbour. Detect and route to a better resampler.
- [ ] Warm cache of the last N thumbnails so scrolling the queue never stalls.

## P2 — Mobile (the weak platform today)

- [ ] **HEIC / HEIF / AVIF decoding** — the largest single gap.
  - [ ] Android: `ImageDecoder` via method channel (API 28+, no extra
        dependency, still zero permissions)
  - [ ] iOS: `ImageIO` / `CoreImage` via method channel
  - [ ] Desktop: `libheif` + `libavif` through FFI
- [ ] **Prefer native decoders for every format** — typically 3–10x faster than
      the Dart codecs. Keep the Dart path as a fallback.
- [ ] **Photo Picker** on Android and `PHPickerViewController` on iOS, so the
      user picks photos without the app holding library access or holding any
      permission.
- [ ] **Share-to-app intent** — "Share → PixelForge" from gallery or camera.
- [ ] **Save back to gallery / Photos** after processing.
- [ ] Background execution: Android foreground service with a progress
      notification, iOS `BGProcessingTask`. The batch must survive the app being
      backgrounded.
- [ ] Haptics on batch completion, edge-to-edge layout, adaptive launcher icon,
      splash screen.
- [ ] Tablet and landscape layouts.

## P3 — Visual design

- [ ] **Live preview that updates while dragging sliders.** Nothing currently
      changes until Process is pressed. This is the single biggest perceived
      quality jump.
- [ ] Draggable **before/after divider** instead of a Before/After toggle.
- [ ] **Multi-output panel** — queue several presets and see every output listed
      per file.
- [ ] Checkerboard behind transparent output.
- [ ] Filmstrip queue with drag-to-reorder, multi-select and range-select.
- [ ] Side-by-side quality/size scatter plot across the batch.
- [ ] Comparison mode: visual diff plus size diff, per file.
- [ ] Honour EXIF orientation in the preview, not just in the output.
- [ ] Design tokens — a single spacing / type / elevation scale. Spacing is
      currently ad-hoc across `lib/ui`.
- [ ] Motion: purposeful, 150–200 ms only.
- [ ] Full RTL support.
- [ ] Real watermark font selection — the bitmap Arial scales badly.
- [ ] Illustration-quality empty states and a first-run onboarding flow.

## P4 — User-friendliness

- [ ] First-run onboarding: the offline guarantee, pick a preset, done.
- [ ] Settings auto-save with debounce. The manual save button is friction.
- [ ] Undo for destructive queue edits.
- [ ] **Per-file overrides** inside a batch.
- [ ] "Apply the same settings again" — remember and replay the last run.
- [ ] Specific error copy. Today every decode failure shares one generic string;
      distinguish corrupt data, unsupported container, native codec missing and
      out of memory.
- [ ] Copy result to clipboard.
- [ ] "Open output folder" / "Reveal in Explorer".
- [ ] Full keyboard shortcuts on desktop.
- [ ] Sort the queue by name, size or date.
- [ ] Duplicate detection.
- [ ] Settings search.
- [ ] Accessibility pass: semantics on every control, screen-reader labels,
      focus order, high contrast, 200% text scaling.
- [ ] Localisation. The strings are already centralised; wire up `flutter_localizations`
      and `intl`.

## P5 — Features competitors have that are missing here

- [ ] **Images → PDF** and **PDF → images**.
- [ ] **ZIP bundle** output instead of loose files.
- [ ] **Face-aware smart crop** (BinaryMark's best feature). Needs a local ONNX
      model; still fully offline, so it fits the privacy story.
- [ ] AI **upscale** — local ONNX, offline.
- [ ] AI **background removal** — local ONNX, offline.
- [ ] **AVIF encode** — the `image` package decodes AVIF but has no AVIF encoder.
- [ ] Watch folder on desktop, plus Explorer right-click integration and
      drag-onto-exe.
- [ ] Save **custom presets**, with JSON import/export.
- [ ] Sprite sheet / CSS sprites generator.
- [ ] Watermark from an **image**, not just text.
- [ ] Blur / redact regions for faces, addresses, licence plates.
- [ ] Dominant colour palette extraction.
- [ ] **CLI** — `pixelforge --preset instagram *.jpg`. Scriptable, headless.
- [ ] RAW: DNG, CR2, NEF.
- [ ] Favicon generator emitting every required size in one run.
- [ ] Multi-size app icon generation from one source.

## P6 — Distribution

- [ ] Real signing config plus Play Store / App Store readiness.
- [ ] Store listing: screenshots, feature graphic, privacy-policy page.
- [ ] Offline crash log written to a file the user can choose to share. No
      telemetry.
- [ ] In-app update check.
- [ ] About and version screen, dependency licence listing.
- [ ] CI smoke test — build the APK, launch it, process one image, assert the
      output dimensions.

---

## Suggested first eight

In the order I would actually tackle them:

1. Animated GIF/WebP preservation — it is silent data loss (P0.1)
2. Real signing config — nothing ships without it (P0.2)
3. Byte-budget solver on a proxy — 8 encodes where 2 will do (P0.4)
4. Isolate worker pool + streaming results — kills the UI freeze and the OOM (P1)
5. Live preview while dragging sliders — biggest perceived-quality jump (P3)
6. HEIC via Android `ImageDecoder` and iOS `ImageIO` — unlocks real phone photos (P2)
7. Photo Picker + share intent + save-to-gallery — makes the mobile build usable (P2)
8. Before/after drag divider + multi-output presets — turns a tool into a product (P3)

## Principles to keep while working through this

- **The offline guarantee is a feature, not a constraint.** Any feature that
  requires a network call does not belong in this app. `test/privacy_test.dart`
  and the CI permission check enforce this; do not weaken them.
- **Never silently degrade.** The WebP lossless-by-default trap, the flattened
  animation frames, and the flattened alpha channels were all silent losses.
  If the pipeline cannot preserve something, say so.
- **Measure before optimising.** The per-file runtime claims should come from
  the benchmark in P6, not from intuition.