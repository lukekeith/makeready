# UI 2.0 Design Tokens

**The normative token source for UI 2.0** — screen specs reference tokens by name, never raw
values where a token exists (DECISIONS.md D7). Populated incrementally from Figma variables
(`get_variable_defs`); first seeding 2026-09-01 from the Home frame (node `3622:5487`, file
`nVva9a2WvYmcWQo6zlHupO`). This file becomes the iPhone design-system doc the app never had —
`Colors.swift` / `Typography.swift` symbols are mapped here where a 2.0 token deliberately
reuses one; the build phase generates code from these tables, not the other way around.

Legacy reference (not normative for 2.0): `iphone/MakeReady/Colors.swift`,
`iphone/MakeReady/Typography.swift`, web `client/resources/css/_palette.scss` chain
(`docs/ui/DESIGN_SYSTEM.md`). The activities theming model (lesson palette → per-page
background → motion preset, `docs/features/activities/04-theming-system.md`) layers on top
of these program tokens and is specced with the activities screens.

## Rules

- Token names are kebab-case, prefixed by family (`color-`, `type-`, `space-`, `radius-`,
  `motion-`, `elevation-`).
- Every row cites its Figma variable (as named in the file) or is marked `observed
  (<screen-id>)` when it recurs in designs without a Figma variable — observed rows are
  provisional until a variable appears or the owner confirms them.
- A raw value in Figma with no variable becomes a token row here **or** a per-screen literal
  flagged in that spec — never a silent magic number.
- iOS / web mapping columns are filled when the value maps onto an existing symbol; `(new)`
  otherwise. Code generation from these tables is a build-phase task.

## Color

| Token | Value | Figma variable | iOS mapping | Web mapping |
|---|---|---|---|---|
| color-layout-background | #030405 | `layout/background` | (new) | (new) |
| color-layout-border | #2f3639 | `layout/border` | (new) | (new) |
| color-card-background | #1f2124 | `card/background` | (new) | (new) |
| color-card-border | #2f363a | `card/border` | (new) | (new) |
| color-accent | #6c47ff | `Purple/100%` | (new) | (new) |
| color-accent-50 | #6c47ff80 | `Purple/50%` | (new) | (new) |
| color-accent-20 | #6c47ff33 | `Purple/20%` | (new) | (new) |
| color-positive | #6cff73 | `green` | (new) | (new) |
| color-negative | #ff4759 | `Red/100` | (new) | (new) |
| color-highlight | #f4ff76 | `Text highlight` | (new) | (new) |
| color-brand-highlight | #c5fff8 | `Brand highlight` | (new) | (new) |
| color-text-primary | #ffffff | `White/100%` / `Label Color/Dark/Primary` / `Color/Base/White` (3 aliases — consolidate: OQ noted below) | (new) | (new) |
| color-text-secondary | #85979e | `text/secondary` | (new) | (new) |
| color-nav-text | #8ea0a7 | `nav/text` (near-duplicate `text/navigation` #8d9fa7 also exists — consolidate: OQ noted below) | (new) | (new) |
| color-white-50 | #ffffff80 | `White/50%` | (new) | (new) |
| color-white-20 | #ffffff33 | `White/20%` | (new) | (new) |
| color-white-10 | #ffffff1a | `White/10%` | (new) | (new) |
| color-neutral-600 | #4a5565 | `Color/Neutral/neutral-600` | (new) | (new) |
| color-input-placeholder | #525d63 | `Input/placeholder` (sheet; conflicts with Default-state usage of `nav/text` — OQ-members-home-4 residual) | (new) | (new) |
| color-input-value | #8ea0a7 | `Input/value` (same hex as `nav/text` — alias) | (new) | (new) |
| color-white-70 | #ffffffb2 | `White/70%` | (new) | (new) |
| color-error | #fb2c36 | `Color/Error/error-500` (distinct from `color-negative` #ff4759 — consolidate: OQ noted below) | (new) | (new) |
| color-brand-primary-bg | #4522d3 | `Background/bg-brand-primary` | (new) | (new) |
| color-neutral-800 | #1e2939 | `Color/Neutral/neutral-800` | (new) | (new) |
| color-neutral-200 | #e5e7eb | `Color/Neutral/neutral-200` | (new) | (new) |
| color-neutral-100 | #edeff2 | `Color/Neutral/neutral-100` | (new) | (new) |
| color-nav-border | #525d60 | `nav/border` | (new) | (new) |
| color-nav-border-active | #8d9fa7 | `nav/border-active` (same hex as `text/navigation` — alias) | (new) | (new) |
| color-nav-tab-background | #1c2124 | `nav/tab-background` | (new) | (new) |
| color-background-alt | #0d101a | `Background` (distinct from `layout/background` #030405 — role unclear, flag) | (new) | (new) |
| color-modal-background | #1f2124 | `modal/background` (same hex as `card/background` — alias) | (new) | (new) |
| color-black | #000000 | `Color/Base/Black` (study-program-home: C-053 badge text on `color-positive`) | (new) | (new) |
| color-transparent | #ffffff00 | `Transparent` (utility zero-alpha; fade/overlay stops) | (new) | (new) |

Token hygiene flags (for the owner, non-blocking): the file carries three white aliases and
two near-identical nav-text grays (#8ea0a7 vs #8d9fa7); `screens/home-dashboard.md` OQ-6
flags a literal #4deb4b progress fill vs `color-positive` — **2026-09-10, C-031's set settles the
evidence and not the ruling: a single symbol spends BOTH greens**, the bound `green` #6cff73 on
the disc's number and the literal #4deb4b on the C-057 bar beside it (OQ-C-031-2). That run also
records a second gap: a status colour at **20% opacity** grounds both C-073 and C-062 and has no
row, where accent has `color-accent-20`. From the component sheet
(2026-09-01): `Input/value` = `nav/text` (same hex), `nav/border-active` =
`text/navigation`, `modal/background` = `card/background`; two error/negative reds
(#fb2c36 vs #ff4759); two placeholder grays (OQ-members-home-4 residual); and a second
background `#0d101a` with unclear role. Consolidation is a Figma cleanup, tracked here so
specs keep citing one token each. From study-program-home (2026-09-01): the `#4deb4b`
progress-fill literal recurs (OQ-home-dashboard-6), and the demographics bar palette
(`#75c8ff` `#b594ff` `#eda3e6` `#4deb4b` `#ceff4e`) has no variables — flagged per-screen
literals pending a categorical-chart-palette ruling (OQ-study-program-home-6). From
enrollments-home (2026-09-02): a THIRD banding literal appears — yellow `#e3eb4b` beside
`#4deb4b`/`#ff4759` on C-057 Thin fills (OQ-enrollments-home-3). From enrollment-home
(2026-09-02): a FOURTH band color `#ffb53e` (C-062 yellow disc), slide placeholder bg
`#2e2e2e`, and a C-063 bar track of White/20% vs C-057's White/10%
(OQ-enrollment-home-3/-4) — the banding ruling now touches four screens. From the C-030
TimeActivityChart set (2026-09-03): the gradient's red stop is raw `#ff4759` — hex-equal
to `Red/100` (`color-negative`) but not variable-bound (OQ-C-030-3, Figma cleanup). From
the C-029 frame (2026-09-03): variable `text/navigation` #8d9fa7 (no token row; the
near-duplicate of `color-nav-text`) is now also consumed as the chart hour-label color —
consolidation pressure grows. From the C-019 TopNav sets (2026-09-05): the whole
`nav/*` family is now consumed by one component — `nav/text`, `nav/border`, `nav/border-active`,
`nav/tab-background` — which is the first evidence that `nav/border-active` (#8d9fa7, hex-equal
to `text/navigation`) is a deliberate role and not just an alias; the C-019 run added no new
color tokens. From the C-034 SearchField set (2026-09-05): no new color variables (`nav/text`, `Color/Base/White`, `Input/placeholder`, `Purple/100%`, `Input/value` are all bound), but the field's
fill `#1f2124` and border `#2f363a` are RAW hex — hex-equal to `color-card-background` /
`color-card-border` and not variable-bound, the same pattern C-045 shows; and the set uses
BOTH placeholder grays as designed states (`nav/text` Default → `Input/placeholder` Focus),
which resolves the cross-set half of OQ-members-home-4 (a) and re-poses it as OQ-C-034-2. From the
C-040 PageHeader set (2026-09-05): no new color variables either (`Purple/100%`,
`White/50%`, `Transparent` are bound; the title's plain white is hex-equal to
`color-text-primary`), and two type rows were added — note `type-page-title` (Regular 14/20)
is the third 14-size row beside `type-body` (Regular 14, leading unmeasured) and
`type-input` (Regular 14/24): whether these are two styles or three is a typography
consolidation the owner should settle before the build phase generates code from this file. From the C-033 GroupFollowCard set (2026-09-10): no new colour variables
(`green`, `Text highlight`, `Red/100`, `White/50%`, `White/100%` are all bound) — but the
card's fill `#1f2124` and border `#2f363a` are RAW hex again, the **third** row after C-034
and C-045 to show that pattern, which is now the rule rather than the exception for card
surfaces; its sub-component **C-072 LinkStatusGlyph** is the first consumer of
`color-brand-highlight` (#c5fff8) in the program; and its root stack gap is **10**, a value
the spacing family (16/16/8/32/4/2/24) has no row for — carried as a flagged per-component
literal under D7 rather than minting a token for a single site. **Superseded 2026-09-10:**
that "occurs exactly once" claim no longer holds — the study-program-home re-spec (frame
`3833:32194`) measures the same **10** as C-063 LessonCard's title-row gap, a second and
unrelated site. Two occurrences is the threshold at which a flagged literal starts looking
like a missing token; the owner should rule on a `space-title-gap` (10) row before the build
phase generates code from this file. From the study-program-home re-spec itself
(2026-09-10): **no new tokens** — every Figma variable on that frame (`Label
Color/Dark/Primary`, `Color/Base/White`, `White/100%`, `White/50%`, `White/20%`,
`Purple/100%`, `text/secondary`, `layout/border`, `Transparent`, `Callout / Bold`) is
already bound, and the frame drops the `green`/`#4deb4b` progress fills and the categorical
demographics palette entirely, so OQ-study-program-home-6's palette half now has no
consuming screen.

## Typography

Fonts: SF Pro (system). The Home frame also uses Inter inside chart annotations — flagged
as OQ-home-dashboard-5, not tokenized (2026-09-03: the owner-designated C-026 set also
sets Inter, evidence toward intentional).

| Token | Font / size / weight / line-height | Figma variable | iOS mapping | Web mapping |
|---|---|---|---|---|
| type-callout-bold | SF Pro Text Semibold 16 / 21, letter-spacing −0.32 | `Callout / Bold` | (new) | (new) |
| type-body-lg | SF Pro Text Regular 17 / 22 | `Body` (sheet) | (new) | (new) |
| type-footnote | SF Pro Text Regular 13 / 18 | `Footnote` (sheet) | (new) | (new) |
| type-title-card | SF Pro Bold 14 / 20 | observed (home-dashboard: KPI + group card titles) | (new) | (new) |
| type-value-emphasis | SF Pro Bold 18 / 24 | observed (home-dashboard: day number, percent circle) | (new) | (new) |
| type-caption | SF Pro Regular 12 / 14 | observed (home-dashboard: metadata, ticks, legends) | (new) | (new) |
| type-caption-bold | SF Pro Bold 12 | observed (home-dashboard: day month/weekday) | (new) | (new) |
| type-caption-semibold | SF Pro Semibold 12 / 12 | observed (home-dashboard: chart max annotation, % glyph — **line-height measured 2026-09-10 at 12/12** by the C-031 full-set run on the `%` glyph of C-073 StatusPercentDisc, one of the two observations already cited here) | (new) | (new) |
| type-body | SF Pro Regular 14 / 14 | observed (home-dashboard: engagement row — **line-height measured 2026-09-10 at 14/14** by the C-031 full-set run, on the very row this token was first observed from: label, count and subtitle all set 14/14; distinct from `type-input`'s 14/24) | (new) | (new) |
| type-section-title | SF Pro Semibold 18 / 24 | observed (study-program-home: section titles; measured — supersedes home-dashboard's "~16 Bold" approximation for C-020, OQ-study-program-home-9) | (new) | (new) |
| type-subtitle-semibold | SF Pro Semibold 14 / 20 | observed (study-program-home: lesson subsection header) | (new) | (new) |
| type-value-hero | SF Pro Regular 24 / 32 | observed (invite-home: recipient phone hero) | (new) | (new) |
| type-action-item | SF Pro Regular 18 / 24 | observed (C-066 ActionMenuOverlay row labels) | (new) | (new) |
| type-nav-label | SF Pro Bold 14 / 16 | observed (C-019 TopNav: tab labels, identical in both presentations; distinct from `type-title-card` Bold 14/**20**) | (new) | (new) |
| type-input | SF Pro Regular 14 / 24 | observed (C-045 TextInput + C-034 SearchField — placeholder, entered value; the program's one input text style) | (new) | (new) |
| type-page-title | SF Pro Regular 14 / 20 | observed (C-040 PageHeader centred title; the same face/size/leading also carries body copy on enrollment-home, invite-home, create-study-program — consolidation candidate, see hygiene note) | (new) | (new) |
| type-nav-action | SF Pro Regular 14 / 24, tracking +0.56 | observed (C-040 PageHeader `Text buttons`: Cancel / Done; distinct from `type-action-item` Regular **18**/24) | (new) | (new) |

## Spacing

| Token | Value (pt/px) | Figma variable | Notes |
|---|---|---|---|
| space-page-margin | 16 | observed (home-dashboard) | leading/trailing content inset |
| space-card-padding | 16 | observed (home-dashboard) | KPI + group cards |
| space-element-gap | 8 | observed (home-dashboard) | card internal stacks, rail gaps |
| space-section-gap | 32 | observed (home-dashboard) | around section divider hairlines |
| space-meta-gap | 4 | observed (home-dashboard) | MetaPair value↔label, meta dots; activities-strip thumbnail gap (study-program-home) |
| space-chip-gap | 2 | observed (study-program-home) | day-rail cells, C-043 chip rows |
| space-row-gap | 24 | observed (study-program-home) | demographics table rows |

## Radius

| Token | Value | Figma variable | Notes |
|---|---|---|---|
| radius-card-sm | 4 | observed (home-dashboard: KPI card) | |
| radius-card | 8 | observed (home-dashboard: group card) | |
| radius-modal | 16 | observed (C-066 ActionMenuOverlay container) | |
| radius-bar | 2 | observed (home-dashboard: sparkline bars) | |
| radius-circle | 50% | observed (home-dashboard: percent circle r32, photo r32) | |

## Motion

| Token | Duration / curve | Figma variable | Notes |
|---|---|---|---|
| motion-menu-fade-in | ≈300ms, ease-out crossfade | measured (Filter.MP4 @20fps, members-home §1) | FilterMenuOverlay open: list + X fade in at fixed positions while page dims; no slide/scale |
| motion-menu-fade-out | ≈250ms, ease-out crossfade | measured (Filter.MP4 @20fps, members-home §1) | Exact reverse of fade-in |

*(Nav morph timings enter with the `shell-topnav` spec from the Robinhood analysis.)*

## Elevation / materials

| Token | Definition | Figma variable | Notes |
|---|---|---|---|
| elevation-thumbnail | 0px 4px 4px rgba(0,0,0,0.2) | observed (study-program-home, superseded frame `3524:29600`) | C-056 activity thumbnails — first shadow in the program. **Orphaned 2026-09-10:** the study-program-home re-spec removed C-056, this token's only consumer, and the C-061 slides that replaced it carry no shadow. The row stands (it records a real measurement) but nothing renders it; it lives or dies with OQ-study-program-home-14 |
