# Edit cover — reference recording (iOS Photos crop editor)

Source: `/Users/lukekeith/MakeReady/Design reference/image editing.MP4` — 1320×2868, 60 fps, 74.1 s.
Sampled at 2 fps (`fps=2,scale=330,tile=6x2` contact sheets) — timestamps ±0.5 s. No moment was
measured at high fps yet; re-extract a window with `ffmpeg -ss <t> -t <d> -vf fps=30` for motion timing.

Chrome (owner frame): Figma 4729:53712 — C-040 header "Edit cover" over an empty page.
Owner deltas from the recording (2026-10-27): no bottom tool bar (Portrait/Adjust/Filters/Crop/Clean Up);
output locked to 16:9 (no aspect controls, no crop-box resizing); no top-right aspect / ⋯ buttons;
top-left = horizontal flip + rotate 90°; top-right = Auto; header Cancel · "Edit cover" · Done.

| t | Demonstrated |
|---|---|
| 0–6 s | Crop mode; straighten dial dragged (−6°, −13°, +14°); image outside the crop box dimmed; rule-of-thirds grid while adjusting |
| 6–12 s | Cancel with changes → popover "Are you sure you want to discard your changes?" · red "Discard Changes"; exit to the photo |
| 12–18 s | Photo viewer (not in scope) |
| 18–24 s | Re-enter editor (Adjust tab → Crop tab) |
| 24–30 s | Straighten −10° → −22° → 0° → +16° → +19°: **zoom auto-increases so no corner ever shows** |
| 30–36 s | Crop-box handle drag (freeform — dropped): black edge visible mid-drag, **springs back to fill on release** |
| 36–42 s | Pan overshoot with black edges, **rubber-bands back**; **rotate 90°** turns the box landscape |
| 42–48 s | Zoom in/out in landscape; **flip** mirrors the image (straighten reads −19 mirrored) |
| 48–54 s | Straighten in landscape (+17°, −5°, +35°, +18°, +3°); aspect menu opened |
| 54–74 s | Aspect presets + "ASPECT RATIO LOCKED" (dropped — 16:9 is fixed) |
