# study-program-home — superseded component contracts (2026-09-01 frame)

**These contracts are preserved, not active.** They were written by the 2026-09-01
`/ui2-screen study-program-home` run against Figma node `3524:29600`, which the owner
superseded on 2026-09-10 with node `3833:32194` (see
[`study-program-home.md`](study-program-home.md) §1). The current frame renders none of
these components, so each row lost its only consumer.

They live here rather than in the screen spec because the screen spec must describe the
screen that exists, and rather than being deleted because the registry is append-only and
these rows still need an anchor: `C-054`, `C-055` and `C-056` point their "Defined in"
column at this file. **OQ-study-program-home-14** decides their fate — struck through,
re-homed on a future frame, or consolidated (C-056 already carries a consolidation flag with
C-061, OQ-enrollment-home-2).

The superseded frame's own snapshot is not retained; the frozen
`screens/assets/study-program-home.png` is the CURRENT frame, and the design version history
for the change is in the capture browser's timeline for this screen.

## Superseded layout (for reference)

The 2026-09-01 frame was 440×1896: cover with a C-053 StatusBadge → Info block (program name
+ description) → 2×2 details grid (Enrollments · Author · Created · Published) → *hairline*
→ Lessons (C-020 header, day rail, ONE lesson block with a C-020 `subsection` header and a
3-wide C-056 strip) → *hairline* → Group Activity (C-020 header, C-031 EnrollmentStatusRow,
"Recent activity" label, 3 × C-054) → *hairline* → Demographics (C-020 header, C-055).

## Contracts

### C-054 GroupEnrollmentCard (new)
Sheet set `3526:30373`, variants `status={Default, Progress}`; 408×88. Consumed here:
`status=Progress` — 16 gap row: **C-038 Avatar** 64 (group photo) + details column
(gap 16): title (`type-title-card`, single line ellipsis) → 8 → completion line (16 gap:
"«n»% complete" SF Pro Regular 14/20 in the status color + **C-057 PercentBar**
Thick/Right, flex) → chip row gap `space-chip-gap` (2): **C-043 MetaChip** Key-value
align=Right "Enrolled «Mon D, YYYY»" + Key-value align=Left "«n» members".
Completion color: `color-positive` at 60% and 18%, `color-negative` at 5% in the frame —
the banding rule is undesigned (OQ-5; same family as OQ-home-dashboard-3). Bar fill
literals per §2 flag. Props: `groupName`, `photoURL`, `completionPercent`, `statusColor`,
`enrolledLabel`, `memberCount`, `onTap`.
**State coverage:** `status=Progress` consumed; `status=Default` designed-unconsumed —
not built without a ruling (OQ-5). No empty/pressed states designed.

### C-055 CategoryBarTable (new)
Frame-local (nodes `3524:29777…29818`), no sheet set. Column-label row (24pt: 100pt
spacer + "% completion" right-aligned in flex + "lessons" right-aligned 100pt, both
`color-text-secondary` 14/16) then five rows (gap 24, each 16pt): age-bin label
(`color-text-secondary` 14/16, 100pt) + bar cell (flex, right-aligned 16pt bar whose
width ∝ % completion) + count label (white 14/16, right-aligned 100pt, abbreviated
"17.3k" formatting). Bins closed: 18 – 25, 26 – 35, 36 – 45, 46 – 60, 61 and up. Bar
colors are the flagged per-screen palette (OQ-6). Props: `rows: [(binLabel, percent,
lessonsLabel)]`.
**State coverage:** one populated instance designed; zero-data and unknown-age handling
are proposed defaults under OQ-7.

### C-056 ActivityThumbnail (new)
Frame-local (nodes `3524:29763–29765`). 140×249, `radius-card` (8), image fill
(object-cover), shadow `elevation-thumbnail` (0 4 4 rgba(0,0,0,0.2)). Props:
`imageURL`, `onTap`.
**State coverage:** only the populated image card is designed. Thumbnail source for
non-video activities and the no-thumbnail fallback are proposed defaults under OQ-8. The
activities-editor/player specs may absorb or extend this row when the pager rows mint.

### C-057 PercentBar (formalized)
Sheet set `3526:30471` ("Percentages") — the bar unit already cited inside C-031 and
C-044; promoted to its own row now that three composites share it (C-031, C-044, C-054).
Track `color-white-10`, fill segment in the consumer's status color (frame literal
anomaly per §2). Variant axes (closed, from the sheet): `style={Thick 16pt, Thin 2pt}` ×
`aligned={Right, Left}` (the `Percent` axis is sample fill levels, not a variant).
Consumed here: Thick/Right (C-031, C-054). C-044 consumes Thin/Left. Props: `progress:
0…1`, `fillColor`, `style`, `aligned`.

