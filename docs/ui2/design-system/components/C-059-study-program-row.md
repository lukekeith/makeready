# C-059 StudyProgramRow — one study program in a list: its identity, its progress, its completion

Status: new · Specced: 2026-09-10 · Owner-designated: `/ui2-component C-059 <set url>` with
the set `3502:28948` pasted by the owner 2026-09-10 and the words *"this is the correct figma
for C-059"* (D10 — the paste designates the SET normative).

**This file consolidates two registry rows into one (owner ruling, 2026-09-10).** The pasted
set was already **C-044 StudyProgramCard's** registered source, while C-059 was sourced from a
*different* set whose 96pt row differs from it in exactly one line. The owner ruled that the
pasted set is C-059's source; **C-044 is struck into this row** (registry, dated) and
`screens/members-profile.md` §4 is repointed here. This closes the consolidation flag the
registry has carried since 2026-09-02.

**Renamed 2026-09-10: EnrollmentProgressRow → StudyProgramRow** (ID stable, registry naming
rules 1/2/4). The row now covers a program's condensed summary, its progress and its
completion across two screens, so a name scoped to "enrollment progress" was narrower than
the consumer set; and the anatomy has no border and no fill, so the family suffix is `-Row`,
not the `-Card` the Figma layer name uses (rule 1 keeps the Figma name in the ref column).

## 1. Normative source

**Primary (owner-designated):**
- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3502-28948
  — frame `3502:28948` ("Study Program Card v2"), 448×412, one axis (`state`), **3** symbols
  on 20pt gutters:

  | Figma symbol | node | size |
  |---|---|---|
  | `state=Condensed` | `3518:29397` | 408×120 |
  | `state=Progress` | `3668:8864` | 408×96 |
  | `state=state4` | `3668:9083` | 408×96 |

- Frozen snapshot: `assets/C-059-study-program-row.png` (896×824, 2×) — captured 2026-09-10

**Folded source (superseded by the ruling, retained as evidence):** two symbols that
`get_design_context` reports as one component named **"Recent Activity"** with a `type` axis —
`type=Lesson` (`3608:4454`, 408×96) and `type=With progress` (`3823:35035`, 408×96). The
latter is the node the registry recorded for C-059 before this run, and it is what the
`enrollments-home` frame renders **today**; its third line is a plain enrolled-date text where
the primary set puts MetaChips (§3d, OQ-C-059-1).
- Frozen snapshots: `assets/C-059-recent-activity-lesson.png`,
  `assets/C-059-recent-activity-with-progress.png` (816×192, 2×) — captured 2026-09-10

**Deviations (closed list):**
1. Every string — "Daily Inspiration", "All are welcome for anyone who needs it", "J. Smith",
   "15 days", "4 enrollments", "12 complete", "15 hours", "31 complete", "92 hours",
   "enrolled Jan 3, 2025" — is per-instantiation content, not part of the contract.
2. The portrait photograph in every thumbnail is placeholder content (one shared source
   image across all five symbols).
3. The set frame is 448×412 with 20pt gutters; the component is the 408-wide symbol, not the
   frame.
4. `state4` is an unnamed Figma placeholder value. This contract uses it verbatim as the
   normative variant value and names its **role** "Complete" in prose only (OQ-C-059-2).
5. In `state4` the progress bar is a **detached copy** of C-057 PercentBar, not an instance.
   It is specced here as C-057 `size=sm, aligned=Left` at 100% (OQ-C-059-4).
6. The two folded "Recent Activity" symbols differ from the primary set in the three measured
   ways listed in §3d. Per the owner's designation those are **drift within one component**,
   not a second component.
7. The set node for the folded "Recent Activity" pair was not resolved — the two symbols sit
   in different parent frames and id ranges, and only their symbol nodes are pinned here
   (residual, non-blocking).

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

Common to all three primary variants:

| Part | Geometry |
|---|---|
| Root | 408 wide, `space-card-padding` (16) top and bottom, content clipped, column, leading-aligned |
| Content row | `space-card-padding` (16) gap, top-aligned: Details column (flexible) + Image (fixed) |
| Details column | flexible width — **328** at the designed 408 (408 − 64 thumb − 16 gap) |
| Title | `type-title-card` (SF Pro Bold 14/20) `color-text-primary`, single line, ellipsized, full width |
| Image | 64×64, `radius-card` (8), clipped; the source is an **88×64 portrait** centred inside it — the card crops, it does not letterbox |

Per-variant deltas:

| | Details gap | 2nd element | 3rd element | Height |
|---|---|---|---|---|
| `Condensed` | `space-card-padding` (16) | description — `type-page-title` (SF Pro Regular 14/20) in **`color-white-50`**, wraps (no ellipsis), `space-element-gap` (8) under the title inside an Info sub-stack | chip row, `space-chip-gap` (2): three **C-043 MetaChip** | 120 (16 + 88 + 16) |
| `Progress` | `space-element-gap` (8) | **C-057 PercentBar** `size=sm, aligned=Left`, 328×2, fill tracks completion | chip row, `space-chip-gap` (2): two **C-043 MetaChip** | 96 (16 + 64 + 16) |
| `state4` | `space-element-gap` (8) | C-057 `size=sm`/`Left` 328×2 **at 100%** (detached — deviation 5) | chip row, `space-chip-gap` (2): two **C-043 MetaChip** | 96 |

The 64pt thumbnail sets the height of both 96pt variants: their detail columns measure 62
(20 + 8 + 2 + 8 + 24), so the image is the taller side and the row is 64 + 32 padding.

**Flagged literals (D7):** the bar fill is raw `#4deb4b` in both `Progress` and `state4` —
hex-distinct from `color-positive` (#6cff73) and the same literal the program has tracked
since home-dashboard (OQ-home-dashboard-6, OQ-enrollments-home-3). No new token is minted
here; see §6 OQ-C-059-9.

**No new tokens.** `get_variable_defs` on the set returns `White/50%`, `White/20%`,
`White/10%`, `Purple/100%`, `green` — all five already bound in `../tokens.md`.

## 3. Variant & state matrix

### 3a. The closed matrix (primary set)

| `state` | 3rd element | Consumption |
|---|---|---|
| `Condensed` | C-043 ×3: `Single/Default` (author) · `Key value/Default` (duration) · `Key value/Purple` (enrollment count) | **designed-unconsumed** — no screen spec renders it |
| `Progress` | C-043 ×2, both `Key value/Default` (completed count, hours) | **consumed** — `members-profile` (Engagement) |
| `state4` | C-043 ×2: `Key value/Complete` (completed count, green) · `Key value/Default` (hours) | **designed-unconsumed** |

Variants not in this table may not be built without a ruling.

### 3b. Undesigned states (proposed defaults + OQ)

None of pressed, disabled, zero-progress or missing-cover is designed. Proposed defaults,
**not fact** (OQ-C-059-7): pressed = whole row at 0.6 opacity for the duration of the touch;
disabled = not offered (no consumer disables a row); zero progress = the C-057 track with no
fill (C-057's own contract governs); missing cover = the thumbnail's 64×64 box filled
`color-white-10` with no glyph.

### 3c. Tappability

`members-profile` §3 records "no affordance shown in source (no chevron): not tappable in v1",
while `enrollments-home` §3 gives the row a tap that pushes `enrollment-home` (screen-map,
2026-09-02). Both remain true of their own screens — the row exposes an optional `onTap` and
neither designs a pressed treatment (OQ-C-059-7).

### 3d. The folded "Recent Activity" symbols

Kept as evidence, not as contract variants. Measured differences from the primary set:

| | `type=Lesson` (3608:4454) | `type=With progress` (3823:35035) |
|---|---|---|
| Closest primary variant | `Condensed` minus the chip row | `Progress` |
| Info gap | `space-element-gap` (8) | `space-card-padding` (16) |
| Title | Bold 14/**20** — matches | Bold 14/**14** — a third Bold-14 leading, tokenless (OQ-C-059-6) |
| 2nd element | description, `type-page-title` in **`color-text-secondary`** (the primary set uses `color-white-50` — OQ-C-059-5) | C-057 `Thin/Left` 328×2 — matches |
| 3rd element | *(none)* | `enrolled «Mon D, YYYY»` — `type-body` (Regular 14/14) `color-text-secondary` (OQ-C-059-1) |
| Height | 96 | 96 |

Both detail columns measure 62pt exactly as the primary set's do — the strongest evidence that
these are one component drawn twice.

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| `state` | `Condensed \| Progress \| state4` | The variant axis, verbatim from Figma (deviation 4) |
| `title` | `String` | Program title — single line, ellipsized in every state |
| `description` | `String?` | `Condensed` only; wraps |
| `progress` | `Double` (0…1) | Drives the C-057 fill; `state4` pins 1.0 |
| `metaChips` | `[C-043 MetaChip]` | The chip row. Count and states per §3a; the chip's own value set is C-043's and is **not** restated here |
| `coverURL` | `URL?` | The 88×64 source the 64×64 box crops |
| `onTap` | `(() -> Void)?` | Optional — see §3c |

The variant maps to props one-to-one: `state` selects the second and third elements and the
Details gap; nothing else in the anatomy varies.

## 5. Composition

**Consumes:** C-043 MetaChip · C-057 PercentBar (`size=sm, aligned=Left`) — contract at
`C-057-percent-bar.md` as of 2026-09-11, which lands one fact this contract did not have:
that variant **draws no track**, so the 328×2 bar in `Progress` and `state4` is a bare
coloured line rather than a filled rail (OQ-C-057-1).

**Consumed by:** `members-profile` (Engagement — `state=Progress`) · `enrollments-home`
(enrollment list — renders the folded `With progress` treatment today, which is OQ-C-059-1).

**Anticipated:** a library or programs screen is the natural consumer of `Condensed` and
`state4`; neither is specced yet.

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-059-1 | Where does the **"enrolled «date»"** line live? Three viable answers: (a) redraw the `enrollments-home` rows as `state=Progress` and drop the date; (b) add an enrolled-date variant to the primary set; (c) render it as a C-043 MetaChip — the C-054 precedent did exactly this (`align=Right`, "Enrolled «date»") before that row was orphaned | No — but the `enrollments-home` build cannot start without it | Owner (design) |
| OQ-C-059-2 | Rename the Figma variant value `state4` to `Complete` — it is the completed state (100% bar + C-043 `Complete` chip) and the placeholder name will otherwise reach generated code | No | Owner (Figma hygiene) |
| OQ-C-059-3 | The `Default` **284pt** variant the C-044 contract recorded **no longer exists** in the set (D5 re-spec event, found this run). Deliberate deletion, or does a planned screen still need a large program card? | No | Owner |
| OQ-C-059-4 | `state4`'s bar is a detached copy of C-057, not an instance — reinstance it so the fill stays governed by one contract | No | Owner (Figma hygiene) |
| OQ-C-059-5 | The description line is `color-white-50` in the primary set and `color-text-secondary` in the folded one. Which token owns a secondary description? | No | Owner |
| OQ-C-059-6 | Title leading is 14/20 everywhere except the folded `With progress` at 14/**14** — a third Bold-14 style beside `type-title-card` (14/20) and `type-nav-label` (14/16). Drift or intent? | No | Owner |
| OQ-C-059-7 | Pressed / disabled / zero-progress / missing-cover are undesigned; §3b proposes defaults | No | Owner |
| OQ-C-059-8 | The folded `type=Lesson` symbol is consumed by no spec and is `Condensed` minus the chip row. Keep it as a variant of this row, or retire it? | No | Owner |
| OQ-C-059-9 | Banding: the set designs only the green fill, but `enrollments-home` observed three band literals on this very row (`#4deb4b` / `#e3eb4b` / `#ff4759`) and `enrollment-home` a fourth (`#ffb53e`). Inherits OQ-enrollments-home-3 / OQ-home-dashboard-6 — one ruling should settle all four | No | Owner |
