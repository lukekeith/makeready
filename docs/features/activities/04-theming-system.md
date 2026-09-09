# 04 — Theming System

## 1. Why the current one can't carry this

Today "theme" means a **timed slide animation** (`TextTheme.definition` → `ThemeBase` subclass →
clock-driven `ThemePlayer` with scrub/pause). The reference experience has no timeline: pages are
scroll-positioned, content entrance is a one-shot choreography, and the visual identity comes from
**tokens** (background, ink, type pairing, scale), not from animation programs. Two parallel theme
players exist (`ThemePlayer.vue` and `themed-content/`), neither of which matches this model.
Both are replaced.

## 2. Three-layer model

### Layer 1 — Lesson palette (`TextTheme` v2, reusing the table)
A **token set**, org-brandable, resolved to CSS custom properties on the pager root:

```jsonc
// TextTheme.definition (v2 shape)
{
  "ink":        { "primary": "#F4F1EA", "muted": "rgba(244,241,234,.62)", "onLight": "#1C1B19" },
  "accent":     "#2E7D74",                       // streak badge, buttons, thumb
  "surfaces":   { "page": "#26262A", "sheet": "#141416", "button": "rgba(255,255,255,.14)" },
  "type": {
    "scripture": { "family": "'Charter', Georgia, serif",  "weight": 400 },
    "voice":     { "family": "InterVariable, system-ui",   "weight": 600 }
  },
  "scale":      { "fontScale": 0.055, "steps": { "S": .8, "M": 1, "L": 1.2, "XL": 1.45 } },
  "quote":      { "rule": true, "ruleColor": "currentColor", "citationCase": "small-caps" },
  "motion":     "gentle"                          // entrance preset name, 05 §6
}
```

- `fontScale` (existing column) stays the width-scaled type mechanism: root font-size =
  `fontScale * 100cqw` on the page container, all text in `em` — the theme-typography Phase 0
  investment carries straight over.
- `maxCharacters` finally gets a consumer: the **editor** mutes scale steps that would overflow a
  page for the given text length (per-page soft budget, not a hard server rule).
- `isSystem` / `organizationId` semantics unchanged; seeding via `server/themes/` +
  `load-themes.ts` continues, with `definition` migrating to the v2 shape under new slugs.

### Layer 2 — Backgrounds (independent of palette)
Two modes, both observed in the reference, both first-class:

- **Lesson backdrop** (video 1): one fixed full-bleed layer behind every page —
  `Lesson.backdrop = { mode: image|video|color, value, scrimOpacity }`. Content scrolls over it;
  it never moves. A scrim guarantees ink contrast.
- **Page background** (video 2): `activity.background` renders an opaque panel that scrolls
  *with* the page, visually overriding the backdrop while that page is on screen. A page may also
  `inherit` (transparent → backdrop shows through). Light panels flip the ink automatically:
  panel declares `tone: light|dark`, pager sets `data-tone` and the palette's `onLight` ink
  applies — same pattern as the app's existing theme-aware SCSS.

Existing `ActivityReadBlock.backgroundImageUrl/Color/overlayOpacity` map 1:1 into page
backgrounds for legacy content.

### Layer 3 — Per-page typography role + scale
`textRole` (SCRIPTURE serif / VOICE sans) and `scale` (S-XL) per activity, defaulted by type
(BIBLE → SCRIPTURE, WRITE prompt → VOICE, prayer TEXT → SCRIPTURE·L, …). The blockquote
treatment (left rule + small-caps citation) is part of the SCRIPTURE role, driven by the palette's
`quote` tokens — not per-activity styling choices.

## 3. Where the old animation themes go

`revealMode` on the activity (03 §4.2) covers the surviving animation identity:
- `GROUPS` (default) — the standard entrance choreography (05 §3).
- `WORDS` — word-by-word reveal (05 §4), the successor to `typewriter`/`dramatic-reveal`.

`bible-reader`'s scroll-mode behavior *is* the pager's native long-page behavior now.
`star-wars`/`bold-slide`-class themes have no home in the member pager; keep them only if a
marketing surface wants them (08 §2) — otherwise delete with `ThemePlayer`.

## 4. Implementation notes

- One SCSS module (`lesson-pager.scss`) consumes only the custom properties; zero per-theme CSS
  files on the client. Server `styles.css` per theme is retired; `theme.json` (v2 tokens) remains
  the on-disk source.
- Token resolution happens once per lesson (server includes the resolved palette in the lesson
  payload) so the pager never fetches `/api/themes` at member runtime.
- Editor theme picker previews = the real pager page rendered small (07 §4), replacing the
  `ThemedContentView.swift` / bundled-HTML approach (dead code, delete).
- Contrast guard: on save, editor computes WCAG contrast of ink vs background (image → sampled
  average under scrim) and warns below 4.5:1 — replaces today's silent bad combinations.
