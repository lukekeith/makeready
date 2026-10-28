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
| color-layout-border | #1c2124 | `layout/border` | (new) | (new) |
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
| color-neutral-50 | #f5f6f7 | `Color/Neutral/neutral-50` | (new) | (new) |
| color-nav-border | #525d60 | `nav/border` | (new) | (new) |
| color-nav-border-active | #8d9fa7 | `nav/border-active` (same hex as `text/navigation` — alias) | (new) | (new) |
| color-nav-tab-background | #1c2124 | `nav/tab-background` | (new) | (new) |
| color-background-alt | #0d101a | `Background` (distinct from `layout/background` #030405 — role unclear, flag) | (new) | (new) |
| color-modal-background | #1f2124 | `modal/background` (same hex as `card/background` — alias) | (new) | (new) |
| color-black | #000000 | `Color/Base/Black` (study-program-home: C-053 badge text on `color-positive`) | (new) | (new) |
| color-transparent | #ffffff00 | `Transparent` (utility zero-alpha; fade/overlay stops) | (new) | (new) |
| color-warning | #ffb53e | **raw — no Figma variable** (OQ-C-062-8). The mid anchor of C-062 PercentDisc's completion ramp (owner ruling 2026-09-11): the third status colour beside `color-positive` #6cff73 and `color-negative` #ff4759, which are the ramp's other two anchors. Minted because the ruling makes it structural rather than incidental — it was previously carried as the "fourth band colour" literal | (new) | (new) |
| color-avatar-fallback | #242a3e | `Border` (C-038 Avatar `Initials` + `Unknown user` ellipse fill — the variable is named `Border` but is bound here as a FILL, and #242a3e is a navy distinct from all three border greys `layout/border` #2f3639, `card/border` #2f363a, `nav/border` #525d60; named for its role, scoped to its one known consumer — OQ-C-038-1) | (new) | (new) |

Token hygiene flags (for the owner, non-blocking): the file carries three white aliases and
two near-identical nav-text grays (#8ea0a7 vs #8d9fa7); `screens/home-dashboard.md` OQ-6
flags a literal #4deb4b progress fill vs `color-positive` — **2026-09-10, C-031's set settles the
evidence and not the ruling: a single symbol spends BOTH greens**, the bound `green` #6cff73 on
the disc's number and the literal #4deb4b on the C-057 bar beside it (OQ-C-031-2). That run also
records a second gap: a status colour at **20% opacity** grounds both the `statusColor` override
and the ramp path of C-062 (one row since the 2026-09-11 merge of ~~C-073~~) and has no
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
phase generates code from this file.  From the **C-059 StudyProgramRow** consolidation (2026-09-10, set `3502:28948` + the
folded "Recent Activity" symbols): **no new tokens** — `White/50%`, `White/20%`, `White/10%`,
`Purple/100%` and `green` are all bound — but the run measures three things this file should
record. (1) The bar fill is the raw `#4deb4b` literal again, in **two** variants of one set, and
that same row is where `enrollments-home` observed `#e3eb4b` and `#ff4759` — the banding ruling
(OQ-home-dashboard-6 / OQ-enrollments-home-3 / OQ-enrollment-home-3) now has a single component
that spends three of the four band colours, which is the cleanest place to settle it
(OQ-C-059-9). (2) A **secondary description line** is drawn in `color-white-50` in one source
and `color-text-secondary` in the other — same role, two tokens, no rule (OQ-C-059-5). (3) A
**third Bold-14 leading** appears: 14/**14**, beside `type-title-card` (Bold 14/20) and
`type-nav-label` (Bold 14/16). It is confined to the superseded source, so no row is minted;
if that treatment survives the OQ-C-059-1 ruling it needs one (OQ-C-059-6). The run also
confirms `type-page-title` (Regular 14/20) carrying body copy for the fourth time — the
consolidation candidate flagged above is now well evidenced.

From the **C-053 StatusBadge** node (2026-09-11, `3524:29722`): **no new tokens** — the node binds
exactly one variable, `Color/Base/Black`. Three flags, all sharpening rows already here. (1) The
pill's green is the raw literal **`#6cff73`**, hex-equal to `color-positive` (`green`) but bound to
nothing, while the label's black IS bound — so one component spends a bound and an unbound colour
side by side. This is the **fifth** component showing the raw-hex-equal-to-a-token pattern after
C-034, C-045, C-033 and C-046's inherited border; at five it is the rule, not the exception
(OQ-C-053-2). (2) The label is **Bold 12 / 16.8 (leading 1.4), tracking −0.24**, where
`type-caption-bold` is recorded as "SF Pro Bold 12" with **no** measured leading and **no**
tracking. Either this measurement completes that row or the tracking makes it a second Bold-12 —
the discriminator is real, since the program's only other negative tracking is
`type-callout-bold`'s −0.32 (OQ-C-053-3). (3) The label is `color-black` at **70%**, and the file
carries `color-white-70` with no black counterpart (OQ-C-053-4).

From the **C-038 Avatar** set (2026-09-11, `4115:31205` "Avatar v2"): **one new token** —
`color-avatar-fallback` (#242a3e), the ground both non-photo states stand on. It is the first
row in this file minted from a Figma variable whose NAME contradicts its binding: the variable
is `Border`, and every other `*/border` variable in the file is a stroke, but here it is an
ellipse fill. It is also a fourth grey in a family that already carries three
(#2f3639 / #2f363a / #525d60) and is the only navy among them, so it is not a consolidation
candidate with any of them — it is a genuinely new role (OQ-C-038-1 asks whether `Border` has
other bindings that would widen the name). The run adds no other row: `White/100%`,
`Transparent` and `Body` are all bound, the fallback glyph is white at **50%** (→
`color-white-50`, read out of the exported vector rather than eyeballed), and the circle is
`radius-circle`. One measurement is carried as a flagged literal instead of a row: the
initials are **SF Pro Text Bold 17 / 22**, an exact-weight sibling of `type-body-lg` (Regular
17/22) drawn by overriding the bound `Body` variable's weight. That is the program's FIRST
Bold-17, and minting `type-body-lg-bold` off a single site would pre-empt the same ruling
`type-title-card` / `type-nav-label` / C-046's Bold 14/14 are already waiting on, so it is
flagged per D7 and asked as OQ-C-038-4. The pending spacing-scale and Bold-leading rulings now
have a third and fourth component behind them.

From the **C-062 PercentDisc** set (2026-09-11, `3822:34382`): **no new tokens** — the set binds
exactly two variables, `green` (#6cff73) and `Red/100` (#ff4759) — but it sharpens three flags
already on file and adds a fourth. (1) The **20%-opacity status ground** is now measured in all six
symbols (green, yellow and red at `0.2`), which makes this set the widest single piece of evidence
for the gap noted above: `color-accent-20` exists and there is no `color-positive-20`,
`color-negative-20` or yellow equivalent. Deliberately NOT minted here — **OQ-C-031-2** already
asks the owner for that ruling and a unilateral mint would pre-empt it. **Narrowed the same day:**
the colour ruling makes C-062's ground an opacity on an *interpolated* colour, which can have no
static token by construction, so OQ-C-031-2's request now survives only for C-062's
**`statusColor` override** (absorbed from ~~C-073~~ 2026-09-11, and now **OQ-C-062-11**), whose disc
is a fixed colour. (2) The **yellow #ffb53e**
is not merely unbound but has **no Figma variable anywhere in the set**, in either of its two
variants, ground and number alike — where green and red both bind. It is the only band colour in
the program with no variable at all — and the **owner's colour ruling the same day** promoted it
from an incidental band to the mid anchor of a red→amber→green completion ramp, which is what
earns it the `color-warning` row above; the missing Figma variable is now the only loose end
(OQ-C-062-8). (3) A **fourth Bold-14 leading** appears: **Bold 14/24**,
beside `type-title-card` (14/20), `type-nav-label` (14/16) and C-046's 14/14 — and unlike those
three its 24 leading already exists in the file on `type-input` and `type-nav-action` (both
Regular 14/24), so the Bold-14 ruling now has a leading it could consolidate *onto* rather than
just choose between (OQ-C-062-3). (4) The `%` glyph is **Semibold 9/12** — the **smallest type in
the program**, 3pt under `type-caption`'s 12, and the first sub-12 row of any kind. Carried as a
flagged literal pending the same ruling.

From the **C-046 FieldGroup** set (2026-09-11, `3524:30092`): **no new tokens** —
`Input/placeholder`, `Purple/100%` and `Color/Base/White` are all bound — and two
measurements that sharpen pending rulings rather than adding rows. (1) Its label is **Bold
14/14**, the SECOND independent site of that leading after the C-059 run found it in a
superseded source; with `type-title-card` (Bold 14/20) and `type-nav-label` (Bold 14/16)
already on file, the program now has three Bold-14 styles and real evidence that 14/14 is
deliberate rather than drift (OQ-C-046-6). (2) Its label↔input gap is **12**, a value the
spacing family (2/4/8/16/24/32) has no row for — a second orphan spacing value beside the
**10** flagged above, and the pair should be settled by one spacing-scale ruling
(OQ-C-046-5). The set also re-confirms the raw-hex card border `#2f363a` inside C-045, the
fourth row to show that pattern.

From the study-program-home re-spec itself
(2026-09-10): **no new tokens** — every Figma variable on that frame (`Label
Color/Dark/Primary`, `Color/Base/White`, `White/100%`, `White/50%`, `White/20%`,
`Purple/100%`, `text/secondary`, `layout/border`, `Transparent`, `Callout / Bold`) is
already bound, and the frame drops the `green`/`#4deb4b` progress fills and the categorical
demographics palette entirely, so OQ-study-program-home-6's palette half now has no
consuming screen.

From the **C-027 LegendItem** set (2026-09-11, `3605:4386`): **no new tokens** — the set binds
exactly three variables (`Purple/100%`, `White/20%`, `text/navigation`) and every one of them is
already accounted for — but it lands two measurements this file should carry. (1) A **THIRD text
consumer of `text/navigation`** (#8d9fa7), the legend label in both variants, after C-029's hour
labels and members-home's Bold 14/22 label. That variable still has **no token row of its own**
while its hex-twin `nav/border-active` does, so three components now cite a bare variable name for
a text colour — and the C-019 note above, which read `nav/border-active` as a deliberate role
rather than an alias, makes it likelier that what is actually missing is a `color-text-navigation`
row, not a consolidation. (2) The program's **first Regular 12/24** text style. No row carries it:
`type-caption` is Regular 12/**14** and was partly observed *from this very legend*, which is why
that citation is withdrawn above. Not minted off one component, per the same D7 reasoning as
C-046's Bold 14/14 and C-029's flagged literals — but it belongs to the same typography
consolidation the owner is already being asked to settle (OQ-C-027-2).

From the **C-035 FilterChip** set (2026-09-11, `3561:33782`): **no new tokens** — all six
variables bind (`Color/Neutral/neutral-800`, `Color/Neutral/neutral-600`, `Color/Base/Black`,
`Color/Base/White`, `text/secondary`, `text/navigation`) — but three things this file should
record. (1) **Attribution fix:** the "members-home Bold 14/22 label" counted above as a
`text/navigation` consumer **is this component**, in two of its four variants. So the consumer
list is C-029's hour labels, C-027's legend and C-035 — three rows, not three screens, and the
variable still has no token row. (2) **A FIFTH Bold-14 leading: 14/22**, on the `type=Menu`
label. The program now carries Bold 14 at 14 (C-046), 16 (`type-nav-label`), 20
(`type-title-card`), 22 (here) and 24 (C-062, and this set's `type=Button` label) — and the last
point is the sharp one: **one component spends two of them**, 22 on its Menu variants and 24 on
its Button variants, differing by variant axis alone. That reads as drift rather than intent and
is the strongest single argument yet for settling OQ-C-062-3 / OQ-C-046-6 as one ruling
(OQ-C-035-3). It also makes C-035 the **second** site of Bold 14/24. (3) `Color/Base/White` is
bound as the **fill** of the active Menu chip, so the program's white is spent as a ground while
`tokens.md` carries it only as `color-text-primary` — the same variable-role mismatch C-038 found
with `Border` bound as a fill (OQ-C-035-4).

From the **C-022 MetaPair** merge (2026-09-11, sets `3636:5616` + `3499:27340`): **no new tokens**
— `text/secondary` and `Color/Base/White` are the only variables either set binds — and three
records. (1) **Regular 12/24 now has a SECOND independent component.** C-027's legend label found
it first; C-022's inline form spends it on both of its runs, and `C-030-time-activity-chart.md`
§2 independently measured the same 12/24 on the tick row it builds from this component. The
program's own threshold for this — stated above for the `10` spacing literal — is that "two
occurrences is the threshold at which a flagged literal starts looking like a missing token", and
that threshold is now met by a **type** row. Recommend minting it before the build phase generates
code; not minted here, because `type-caption` (Regular 12/**14**) sits one leading away and the
two should be settled together (OQ-C-022-3). (2) **The stacked form needs no new row** — its
Regular 14 / leading-none matches `type-body` (Regular 14/14) exactly, the first clean re-use of
that row outside home-dashboard's engagement row. (3) **One row, two white bindings.** The stacked
set binds `Color/Base/White`; the inline set binds **nothing** for its value run — plain white,
hex-equal to `color-text-primary` and not variable-bound. Since the owner merged these into one
registry row, C-022 now contains both a bound and an unbound white for the same role
(OQ-C-022-4) — the raw-hex pattern C-034/C-045/C-033/C-046/C-053 established, appearing for the
first time *inside* a single row.

From the **C-064 DateSpanIndicator** full-set run (2026-09-11, set `3836:7921`): **no new tokens**
— the symbol binds exactly three variables (`White/20%`, `Color/Base/White`, `text/secondary`),
all of which already have rows — and three records. (1) **Regular 12/24 now has a THIRD independent
component.** C-027 LegendItem found it, C-022 MetaPair's inline form spends it on both runs (with
C-030 measuring it a fourth time on the tick row it builds from C-022), and C-064's two pairs make
three rows measuring it from three separate Figma sets. The threshold stated above was met at two;
this is the second run in a row to recommend minting it and decline, for the same reason —
`type-caption` (Regular 12/**14**) sits one leading away and the two should be settled together
(OQ-C-022-3). The recommendation is getting harder to defer: the build lane is already emitting it
as a flagged literal in `UI2Preview/LegendItem.swift` and `UI2Preview/MetaPair.swift`. (2) **New
evidence on OQ-C-022-4, and it points at "bind it".** That OQ asks why C-022's stacked set binds
`Color/Base/White` for its value while its inline set binds nothing for the same role. C-064's
pairs are the inline anatomy exactly — Regular 12/24, white value, `text/secondary` label — and
**they DO bind `Color/Base/White`**. So the unbound white is specific to set `3636:5616`, not a
property of the inline form; that reads as an authoring miss in one set rather than a deliberate
second white. (3) **`color-white-20` gains a glyph-fill consumer.** C-075 ArrowGlyph (minted this
run, contract in `components/C-064-date-span-indicator.md` §5a) bakes it into the exported vector
rather than tinting at the call site — the same baked-fill pattern C-072 and C-074 record, and the
first time the program spends this token on artwork rather than on a border or a dimmed text run.

From the **C-052 DayChip** set (2026-09-11, `3495:2778`): **no new tokens** — the set binds
exactly two variables, `White/20%` and `Purple/100%`, both of which have rows — and three
records. (1) **`type-body` gets its second clean re-use.** The day number measures SF Pro
Regular **14 / 14** in both symbols (text box 7×**14** at 14pt = `leading-none`), matching that
row exactly. The note above called C-022's stacked form "the first clean re-use of that row
outside home-dashboard"; this is the second, and — unlike the five-way Bold-14 tangle
(OQ-C-046-6 / OQ-C-062-3 / OQ-C-035-3) — the program's Regular-14/14 row is now behaving like a
settled style rather than a consolidation candidate. (2) **A seventh raw-hex site, and the
second on a white text run.** The number's `#ffffff` binds nothing while both chip fills do —
the inverse of C-053, whose fill is raw and whose label is bound. C-022's inline value is the
other text-run case, and OQ-C-022-4 asks the identical question, so the two should be answered
together (OQ-C-052-2). (3) **`color-white-20` is spent as a translucent GROUND on a tappable
surface** for the first time. Every other consumer on file uses it for a border, a dimmed run,
a bar track or C-075's baked glyph fill; here it is the unselected chip's background, and the
20% alpha is the contract — the `#4b4b4b` a snapshot shows is that fill over Figma's `#1e1e1e`
authoring ground, and over `color-layout-background` the same fill reads ≈`#363738`. Worth
recording because it is exactly the kind of value a build hard-codes off a screenshot.

From the **C-057 PercentBar** set (2026-09-11, `3526:30471`): **no new tokens** — and this is the
run that should decide whether that stays true, because the set is the **widest single piece of
evidence for the banding ruling this file has been accumulating since 2026-09-01**. Three
records. (1) **Twenty-four symbols, one bound variable.** `get_variable_defs` on the whole set
returns exactly `White/10%` (the track). Every fill colour is raw: `#ff4759` (hex-equal to
`color-negative`), **`#e3eb4b`** and **`#4deb4b`** — and the last two have no token *and no
Figma variable anywhere*, which until now was true only of C-062's `#ffb53e`. (2) **The two
ramp-bearing components disagree on two of three colours.** C-062 PercentDisc's ruled completion
ramp is #ff4759 → `color-warning` #ffb53e → `color-positive` #6cff73. C-057's samples run
#ff4759 → #e3eb4b → #4deb4b. Same red, **different amber, different green**. So the program does
not have one ramp drawn twice; it has two ramps that share a red. That is a sharper statement of
OQ-home-dashboard-6 / OQ-enrollments-home-3 / OQ-enrollment-home-3 / OQ-C-031-2 / OQ-C-059-9 /
OQ-C-062-8 than any of them makes alone, and it is carried as OQ-C-057-2. Nothing minted here,
for the same reason C-062's run declined to mint a `color-positive-20`: `color-warning` was
minted only *after* the owner ruled, and minting #4deb4b or #e3eb4b now would pre-empt the same
ruling from the other side. (3) **`radius-bar` (2) has no consumer here.** The row is named
`-Bar` and is the program's linear progress unit, and its corners are **square** in all
twenty-four symbols — Figma types the fill `rounded-rectangle` but draws no radius. That token
is still evidenced only by home-dashboard's sparkline bars (C-024), so the family it sounded
general to turns out to be one component wide.

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
| type-caption | SF Pro Regular 12 / 14 | observed (home-dashboard: metadata, ticks, ~~legends~~ — **the "legends" observation is WITHDRAWN 2026-09-11**: the C-027 LegendItem set measures its label at Regular 12/**24**, in both variants, so the legend never evidenced this row. Metadata and ticks stand) | (new) | (new) |
| type-caption-bold | SF Pro Bold 12 | observed (home-dashboard: day month/weekday) | (new) | (new) |
| type-caption-semibold | SF Pro Semibold 12 / 12 | observed (home-dashboard: chart max annotation, % glyph — **line-height measured 2026-09-10 at 12/12** by the C-031 full-set run on the `%` glyph of ~~C-073 StatusPercentDisc~~, one of the two observations already cited here. ⚠️ **That observation is now historical:** the 2026-09-11 merge into C-062 dropped C-073's type scale, so nothing renders Semibold 12/12 on that disc any more — the row's other observation, home-dashboard's chart max annotation, is what still evidences it) | (new) | (new) |
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
