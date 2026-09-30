# C-057 PercentBar — the linear progress unit the program's composites share

Status: new · Specced: 2026-09-11 · Owner-designated: `/ui2-component C-057 <node url>` with
the sheet frame `3526:30471` ("Percentages") pasted by the owner 2026-09-11 (D10). The pasted
node is the variant set itself, not an instance.

**Contract relocated this run.** The row's contract was an eight-line "formalized" block frozen
in [`../screens/study-program-home-superseded-contracts.md`](../screens/study-program-home-superseded-contracts.md)
§4, with a three-line pointer in the live `screens/study-program-home.md` §4 saying "No contract
change; the formalization stands". This file replaces both. The relocation is overdue: **three
other component contracts already delegate to this row** — C-031 §5 ("`progress` and the bar's
geometry delegate to C-057 PercentBar; that row owns the …"), C-033 §5 (identical sentence),
C-059 §3a — so until now three contracts deferred to a contract that was eight lines long and
lived in an archive of a superseded frame.

**What this run corrects in the relocated text** (closed list — the formalization was right on
everything else):
1. It said "`style={Thick 16pt, Thin 2pt}` × `aligned={Right, Left}`" **as if the four variants
   differed only in those two measurements**. They do not: `Thin` + `Left` — six of the
   twenty-four symbols, and the variant **two of the three consuming rows use** — draws **no
   track at all** (§3a, §1 deviation 3).
2. It said the fill is "in the consumer's status color (frame literal anomaly per §2)",
   naming one anomaly. The set has **three** unbound fill colours and **not one of them is a
   token**: `#ff4759`, `#e3eb4b`, `#4deb4b`. Only the track binds a variable (§2).
3. It recorded the `Percent` axis as "sample fill levels, not a variant" — correct, and this
   run **proves** it rather than asserting it: the six percents are drawn at **two different
   hand-drawn width series** depending on `aligned`, and neither series equals `percent × 255`
   (§3b). The source therefore never demonstrates the fill law.
4. It listed consumers as "Thick/Right (C-031, C-054); C-044 consumes Thin/Left". C-044 is
   **struck** (absorbed into C-059, 2026-09-10) and C-054 is **orphaned** (2026-09-10); the live
   consumer set is C-031, C-033 and C-059 (§5).
5. The frozen snapshot is re-exported at **4×** (the program's current scale, matching C-052 and
   C-053), replacing the 3× export on disk. Same node, same framing.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3526-30471
  — set `3526:30471` ("Percentages"), 666×568, on the component sheet (`3632:4502`), ingested
  2026-09-11.
- **Three axes, twenty-four symbols.** `Percent` {5, 10, 25, 40, 60, 80} × `style` {Thick, Thin}
  × `aligned` {Right, Left}. All three axis names and every value name are **author-written**,
  not Figma's `Property 1` / `Variant2` placeholders, so registry rule 6 requires no rename —
  only the record that the strings were checked (§3b covers why `Percent` is nonetheless dropped
  rather than renamed).
- Symbol nodes, by family:

  | Family | Symbols (`Percent=5, 10, 25, 40, 60, 80`) |
  |---|---|
  | `Thick` / `Right` | `3526:30480` · `3526:30478` · `3526:30470` · `3526:30472` · `3526:30474` · `3526:30476` |
  | `Thin` / `Right` | `3621:4686` · `3621:4688` · `3621:4690` · `3621:4692` · `3621:4694` · `3621:4696` |
  | `Thick` / `Left` | `3621:4731` · `3621:4735` · `3621:4739` · `3621:4743` · `3621:4747` · `3621:4751` |
  | `Thin` / `Left` | `3621:4733` · `3621:4737` · `3621:4741` · `3621:4745` · `3621:4749` · `3621:4753` |

- Frozen snapshot: `assets/C-057-percent-bar.png` — the whole set at 4×, captured 2026-09-11.
- Verified against a live instance: C-033's `style=Default` card embeds `3621:4698`, which
  resolves to `3621:4753` (`Percent=80, style=Thin, aligned=Left`) — and carries the same
  no-track construction (§1 deviation 3).

**Deviations (closed list):**
1. **`Percent` is not a variant axis, it is sample content.** The six values are labels on
   hand-drawn fill widths; §3b gives both series and shows neither computes. The prop is
   `progress` and 5/10/25/40/60/80 are its designed sample values, so the axis is **dropped**
   rather than renamed (registry rule 6's "an axis that turns out not to be a prop is dropped").
2. **The track width is the sheet's, not the component's.** Every symbol is 255 wide because
   that is the sample frame; the live consumers are 255 (C-031), 145 (C-033) and 328 (C-059).
   The bar fills the width its host gives it and takes no width prop (§4).
3. **`Thin` + `Left` draws no track.** Its container carries `h-[2px] items-start overflow-clip`
   and **no background**, where the other three families carry
   `bg-[var(--white/10%)]`. Six of twenty-four symbols, and the variant C-033 and C-059 both
   consume. Recorded as the source's fact; OQ-C-057-1 asks whether it is intended.
4. **The corners are square.** Figma types the fill node `rounded-rectangle`, but the generated
   geometry carries no `rounded-*` and the exported pixels show a hard corner at every fill edge.
   `tokens.md` has `radius-bar` (2) from home-dashboard's sparkline bars; **this component does
   not use it**.
5. **`Thick` declares no height of its own.** Its container is a flex column with no height; the
   16 comes from the fill child. `Thin` declares `h-[2px]` explicitly. The consequence at
   `progress = 0` is §3c's, not a detail.
6. **Only the track binds a Figma variable.** `get_variable_defs` on the whole set returns
   exactly `{"White/10%": "#ffffff1a"}`. All three fill colours are raw literals (§2).

7. **Three of this row's axes are ruled by a NOTE, not by Figma.** Note
   `2026-09-12T02:28:29.097Z` renames the thickness axis to t-shirt sizes (Figma `Thin` → `sm`,
   `Thick` → `lg`) and **adds** an `md` between them, adds a `fillStyle` {solid, gradient}
   axis, re-scopes `fillColor` to an override over a threshold-derived default, and adds a
   fill animation. A note supersedes the contract per property
   (`docs/features/ui2-component-notes/01-architecture.md` D3/R13), so §3 and §4 below are the
   note's contract, not the set's. **The Figma strings are preserved here as source evidence
   only**: the set's axis is spelled `style` with values `Thick` and `Thin`, and nothing in
   Figma draws `md` or a gradient.

Anything else that differs from the source is a defect.

## 2. Anatomy & geometry

Two rectangles: a full-width track and a fill anchored to one end of it. No label, no border, no
radius, no shadow, no tick marks.

| Part | Geometry |
|---|---|
| Track | full width of the host slot (255 in the sheet); fill `color-white-10`; **square corners**; `overflow: clip` at `sm`. **Absent at `sm` + `Left`** — Figma's `Thin`/`Left` (§1 deviation 3) |
| Fill | height = the track's; width = `progress` × the track's width (§3b); **square corners**; colour = `fillColor` (§4). Anchored to the end `aligned` names — `items-end` for `Right`, `items-start` for `Left` |
| Height | `size` selects it: `sm` **2** · `md` **8** · `lg` **16**. Figma's `Thin` declares its 2 on the container; its `Thick` takes its 16 *from the fill child* (§1 deviation 5), and `md`'s 8 is the build's pick (OQ-C-057-8). This contract puts the height on the component in all three, so a zero fill cannot collapse it (§3d) |

**Flagged literals (D7) — the entire colour vocabulary except the track.** The set spends three
fill colours and binds none of them:

| Literal | Nearest token | Status |
|---|---|---|
| `#ff4759` | `color-negative` (#ff4759) | **hex-equal but unbound** — the only one of the three that even has a hex twin |
| `#e3eb4b` | none | **no token, no variable.** The "third banding literal" `tokens.md` records from enrollments-home (OQ-enrollments-home-3), now measured at its source |
| `#4deb4b` | none — `color-positive` is **#6cff73** | **no token, no variable.** The green OQ-home-dashboard-6 has been chasing since 2026-09-01 |

They are emitted as literals, not promoted, because promoting them would assert bindings Figma
does not have — and in two of the three cases there is no token to promote them *to*.

**This set is the widest single piece of evidence for the pending banding ruling, and it says
the two ramp-bearing components disagree.** C-062 PercentDisc's completion ramp (owner ruling,
2026-09-11) runs `color-negative` #ff4759 → `color-warning` #ffb53e → `color-positive` #6cff73.
C-057's samples run #ff4759 → **#e3eb4b** → **#4deb4b**. Same red; **a different amber and a
different green**. Two components that both express "how complete is this" share exactly one of
their three colours. Not resolved here — OQ-C-057-2, which is the same ruling
OQ-home-dashboard-6 / OQ-enrollments-home-3 / OQ-enrollment-home-3 / OQ-C-031-2 / OQ-C-059-9 /
OQ-C-062-8 are all waiting on.

**Tokens.** `get_variable_defs` on the set returns exactly one variable, and it has a row.
**This run mints no token** — deliberately, because minting either missing band colour would
pre-empt the ruling above, the way `color-warning` was minted only *after* the owner ruled.

| Token | Value | Figma variable | Used by |
|---|---|---|---|
| `color-white-10` | #ffffff1a | `White/10%` | the track, in three of the four families |

## 3. Variant & state matrix

### 3a. The closed matrix

Three axes, twelve variants. `Percent` is dropped per §1 deviation 1; `size` and `fillStyle`
are the note's per §1 deviation 7.

| `size` | `aligned` | `fillStyle` | Track | Height | Fill | Consumption |
|---|---|---|---|---|---|---|
| `sm` | `Right` | `solid` | `color-white-10` | 2 | one colour, right-anchored | **designed-unconsumed** (Figma `Thin`/`Right`) |
| `sm` | `Right` | `gradient` | `color-white-10` | 2 | ramp, right-anchored | **unconsumed — note-created**, no Figma symbol |
| `sm` | `Left` | `solid` | **none — no background is drawn** | 2 | one colour, left-anchored | **consumed** — C-033 GroupFollowCard (`style=Default`) · C-059 StudyProgramRow (`Progress`, and `state4` as a detached copy, OQ-C-059-4) |
| `sm` | `Left` | `gradient` | **none — no background is drawn** | 2 | ramp, left-anchored | **unconsumed — note-created**, no Figma symbol |
| `md` | `Right` | `solid` | `color-white-10` | 8 | one colour, right-anchored | **unconsumed — note-created**, no Figma symbol |
| `md` | `Right` | `gradient` | `color-white-10` | 8 | ramp, right-anchored | **unconsumed — note-created**, no Figma symbol |
| `md` | `Left` | `solid` | `color-white-10` | 8 | one colour, left-anchored | **unconsumed — note-created**, no Figma symbol |
| `md` | `Left` | `gradient` | `color-white-10` | 8 | ramp, left-anchored | **unconsumed — note-created**, no Figma symbol |
| `lg` | `Right` | `solid` | `color-white-10` | 16 | one colour, right-anchored | **consumed** — C-031 EnrollmentStatusRow. Formerly also ~~C-054~~ (orphaned 2026-09-10) |
| `lg` | `Right` | `gradient` | `color-white-10` | 16 | ramp, right-anchored | **unconsumed — note-created**, no Figma symbol |
| `lg` | `Left` | `solid` | `color-white-10` | 16 | one colour, left-anchored | **designed-unconsumed** (Figma `Thick`/`Left`) |
| `lg` | `Left` | `gradient` | `color-white-10` | 16 | ramp, left-anchored | **unconsumed — note-created**, no Figma symbol |

Variants not in this table may not be built without a ruling.

**Which rows Figma actually draws.** Only the four `solid` rows at `sm` and `lg` have symbols in
`3526:30471` — they are the set's `Thin`/`Thick` × `Right`/`Left`, renamed. The other eight are
the note's, and they are listed here rather than parked as proposals because the note **is** the
ruling: `md` and `gradient` are owner-designated behaviour, not a build's guess (§1 deviation 7).
What they are not is *drawn*, so they have no Figma side to diff against and the browser shows
them built-only.

**Two consumed rows, diagonal opposites.** `lg`/`Right`/`solid` and `sm`/`Left`/`solid` — the
thickest with a track at the right end, and the thinnest with no track at the left. The axes have
never been exercised independently by a consumer.

**The no-track rule is `sm` + `Left`, and it is Figma's** (§1 deviation 3). `md` is note-created
and no symbol pairs it with `Left`, so it follows the tracked majority; that is a build decision
the note does not make — OQ-C-057-7.

### 3b. Why `Percent` is a prop, not an axis — the evidence

The six `Percent` values are drawn at **two different hand-drawn width series**, in a 255pt
track:

| `Percent` | Figma `Thick`/`Right`, `Thick`/`Left`, `Thin`/`Right` | Figma `Thin`/`Left` | `progress × 255` would be |
|---|---|---|---|
| 5 | 3 | 22 | 12.75 |
| 10 | 10 | 48 | 25.5 |
| 25 | 29 | 79 | 63.75 |
| 40 | 44 | 125 | 102 |
| 60 | 66 | 161 | 153 |
| 80 | 81 | 222 | 204 |

Neither column is `percent × 255`, neither is `percent × k` for any single `k`, and the two
disagree with each other for the same stated percentage. So the source draws **samples**, not a
law — which is what C-031 §1 deviation 7 ("the bar's fill length is C-057 sample content") and
C-033 §1 deviation 8 ("the fill length is sample content, not a designed value") each recorded
from one end. The only coherent reading is `fill width = progress × track width`, and this
contract states it as the contract while recording that the source does not demonstrate it —
OQ-C-057-4.

**The sample colours band, and the two families put the boundary in different places:**

| `Percent` | Figma `Thick`/`Right`, `Thick`/`Left`, `Thin`/`Right` | Figma `Thin`/`Left` |
|---|---|---|
| 5 | `#ff4759` | `#ff4759` |
| 10 | `#e3eb4b` | `#e3eb4b` |
| 25 | `#4deb4b` | **`#e3eb4b`** |
| 40 · 60 · 80 | `#4deb4b` | `#4deb4b` |

One set, one stated percentage, two colours. That eyeballed-sample signature is why the note
replaced the source's implied banding with **explicit thresholds** (§4) rather than a rule read
off these samples — and it is what closes OQ-C-057-3.

### 3c. How the fill resolves — the note's rule

Note `2026-09-12T02:28:29.097Z`, in full force here:

- **`fillColor` wins outright.** A caller-supplied colour is the fill, in either `fillStyle`.
  Both live consumers do exactly this (C-031 passes its row's status colour, C-033 passes its
  own `#4deb4b` literal), so today every *consumed* render is an override.
- **Otherwise the colour derives from `progress` against `thresholds`.** The three stops are
  sorted by value before use, so any authoring order works and whichever colour carries the
  lowest threshold becomes the floor band.
- **`solid`** paints the band `progress` has reached — the highest threshold at or below it, and
  the floor band beneath the lowest.
- **`gradient`** lays the ramp across the **whole track**, with stops at the threshold
  fractions, and the fill's width reveals as much of it as `progress` reaches. The note's own
  example: "if the bar is 90%, it would gradiate from the red threshold -> yellow threshold ->
  green threshold and interpolate all the colors inbetween." Anchoring the ramp to the *fill*
  instead would slide every colour as the bar grew, which is not what "the red threshold" names.
  The ramp's origin is the anchored end, because that is where the value axis starts.

### 3d. Undesigned states (proposed defaults + OQ)

- **`progress = 0`.** No symbol draws it, and the construction makes it consequential rather
  than trivial: Figma's `Thick` takes its 16pt height *from the fill*, so a zero-width fill would
  leave the track with no height at all (§1 deviation 5). Proposed default: the track renders at
  its variant's height (2 / 8 / 16) with no fill; the height is the component's, not the fill's.
  OQ-C-057-5.
- **`progress = 1`.** Not drawn either — the highest sample is 80. Proposed default: the fill
  covers the track exactly. (C-059 `state4` already pins 1.0 and draws it as a **detached copy**,
  which is why that row carries OQ-C-059-4.)
- **`progress > 1` / negative.** Not drawn and **not proposed** by the source: `sm`'s
  `overflow: clip` means an over-long fill is silently clipped, which is how C-033's 222pt fill
  reads as full inside its 145pt slot. Clamping to 0…1 is the build's decision and produces the
  same result.
- **Interaction.** No pressed, disabled, hover or focus symbol, and no action prop — the bar is
  a read-out. Proposed default: non-interactive.
- **Animation.** `fillAnimation` is the note's, and nothing in Figma draws motion. Default `nil`
  — no animation — which is also what every fixture passes, because an animating fill would make
  a still capture race the transition.

## 4. Props contract

Rewritten by note `2026-09-12T02:28:29.097Z` (§1 deviation 7). The note's words are quoted where
they are the whole justification for a prop.

| Prop | Type | Purpose |
|---|---|---|
| `progress` | `Double` (0…1) | The fraction of the track the fill covers. `fill width = progress × track width` (§3b — stated by this contract, not demonstrated by the source, OQ-C-057-4). Clamped |
| `fillColor` | `Color?` | **The override.** "I want the calling surface to have control over the color as an override." Non-nil wins in both fill styles; `nil` derives the colour from `progress` and `thresholds` (§3c). The prop **name** is the set's original — a note re-scopes semantics, it does not rename |
| `size` | `sm \| md \| lg` | The bar's height: **2 / 8 / 16**. "the thickenss of the bar is done with a t-shirt size where the thin variant in figma is the sm and the thick variant is the lg, we just need one inbetween for md." `sm` and `lg` map onto the set's `Thin` and `Thick` exactly; `md`'s 8 is the build's pick, OQ-C-057-8 |
| `aligned` | `Right \| Left` | Which end of the track the fill is anchored to — `items-end` / `items-start` on the source's flex container. The one axis the note leaves alone |
| `fillStyle` | `solid \| gradient` | "a prop to set whether or not we are filling with a gradiation or filling solid." Inert while `fillColor` is non-nil |
| `thresholds` | `Thresholds` | The ramp stops, each 0…1, **in any order** — sorted before use. "there should be a default applied 0.2 red, 0.4 yellow 0.7 green", which is the default |
| `fillAnimation` | `FillAnimation?` | "the bar filling from 0 -> it's value at a duration with an easing function" — a `duration` and one of `linear \| easeIn \| easeOut \| easeInOut`. `nil` = no animation (§3d) |

**No width prop.** The bar fills the width its host gives it (§1 deviation 2); 255 is the
sheet's sample, and the three consumers instantiate it at 255, 145 and 328.

**No label prop.** Every percentage string beside a bar in the program belongs to the host —
C-033's "55% complete" row, C-031's C-062 disc, C-059's MetaChips. This component draws no text.

**The three ramp colours are not props and not tokens.** They are §2's flagged literals
`#ff4759` / `#e3eb4b` / `#4deb4b`. The note asks for "red, yellow, and green" without saying
which, so it settles the mechanism and leaves the palette to OQ-C-057-2.

## 5. Composition

**Consumes: nothing.** Verified against the set's subtree, not assumed — every symbol is a
container with exactly one rectangle child. No nested instances, no vectors, no text.

**Consumed by** — three live rows, and through them four screens:

| Row | Variant | Geometry there |
|---|---|---|
| **C-031** EnrollmentStatusRow | `Thick` / `Right` | 255×16, flexes with the row |
| **C-033** GroupFollowCard | `Thin` / `Left` | 145×2, `style=Default` only (itself designed-unconsumed at screen level) |
| **C-059** StudyProgramRow | `Thin` / `Left` | 328×2 in `Progress`; `state4` is a detached copy at 1.0 (OQ-C-059-4) |

~~C-044~~ struck 2026-09-10 (absorbed into C-059). ~~C-054~~ orphaned 2026-09-10
(OQ-study-program-home-14). Screens reached through the rows above: `members-profile`,
`enrollments-home`, `home-dashboard` (via C-033 `Default`, designed-unconsumed).

**Not a consumer, and worth naming so:** **C-063 LessonCard**'s `withProgress` bar is its own
2pt drawing with a `color-white-20` track, where this row's is `color-white-10` — a same-role
divergence already flagged as OQ-enrollment-home-4. If that ruling goes this row's way, C-063
becomes a fourth consumer; if it does not, the program has two progress bars by design.

**Anticipated:** any 2.0 surface that shows completion linearly. It is deliberately distinct
from the program's other two quantity components:

| Row | Anatomy | Renders |
|---|---|---|
| **C-057 PercentBar** | track + fill, 16 or 2 tall, square | **one** value as a proportion of a length |
| C-062 PercentDisc | ring + centred number | **one** value as a proportion of a circle, with its own ramp |
| C-024 SparkBarChart | a row of bars | a **series** over a period (its §5 already names this distinction) |

## 6. Open questions

| # | Question | Blocks? | Who decides |
|---|---|---|---|
| OQ-C-057-1 | **`Thin`/`Left` draws no track — intended, or an authoring miss?** Six of twenty-four symbols omit the `color-white-10` background, and it is the variant **both** thin consumers use, so C-033's and C-059's bars are bare coloured lines with no rail. Verified on a live instance (`3621:4698` → `3621:4753`), so it is not a set-only artefact. Either the thin bar is deliberately rail-less and the other three families are the inconsistency, or one fill is missing. Both consuming contracts describe a "track" in prose, which suggests the miss — but neither measured it | No — the source is unambiguous about what it draws | Owner |
| OQ-C-057-2 | **The whole colour vocabulary is unbound, and it contradicts C-062's ramp.** `#ff4759` (hex-equal to `color-negative`), `#e3eb4b` (no token anywhere) and `#4deb4b` (no token; `color-positive` is #6cff73) — while C-062's ruled ramp is #ff4759 → `color-warning` #ffb53e → `color-positive` #6cff73. Two components expressing completion share one of three colours. This set is the widest evidence yet for the ruling OQ-home-dashboard-6 / OQ-enrollments-home-3 / OQ-enrollment-home-3 / OQ-C-031-2 / OQ-C-059-9 / OQ-C-062-8 are all waiting on, and the cleanest place to settle it: bind C-057 to C-062's anchors, or declare the bar's palette independent | No — the literals are emitted as drawn | Owner |
| ~~OQ-C-057-3~~ | ~~**Is `fillColor` a prop, or does this row own a banding rule?**~~ **CLOSED 2026-09-12 by note `2026-09-12T02:28:29.097Z`** — it is **both**, in the shape the OQ guessed at: the row owns a threshold ramp and `fillColor` is the caller's **override** over it (§3c, §4). The thresholds are themselves props with the note's defaults (0.2 / 0.4 / 0.7), so the banding rule is configurable rather than baked. What the note does **not** settle is which three colours the ramp uses — that stays OQ-C-057-2 | — | closed |
| OQ-C-057-4 | **The source never demonstrates the fill law.** Two hand-drawn width series for the same six percentages, neither equal to `percent × 255` (§3b). This contract states `fill = progress × track width` as the only coherent reading. Confirm it — or, if the samples encode something else (a minimum visible fill, a non-linear scale), say what | No — stated as the contract | Owner |
| OQ-C-057-5 | **`progress = 0` has no height in `Thick`.** The 16 comes from the fill child, not the container (§1 deviation 5), so a zero-progress thick bar collapses. §3c proposes the track keeps its variant's height regardless. Confirm, or design the empty state | No — default proposed | Owner |
| OQ-C-057-7 | **Does `md` + `Left` draw a track?** The no-track rule is Figma's and it is specific to `Thin`/`Left` (§1 deviation 3). `md` is note-created and no symbol pairs it with `Left`, so the build follows the tracked majority and draws one. If the rail-less hairline is a deliberate treatment for *thin left-anchored* bars rather than for that one symbol, `md`/`Left` should lose its track too. Pairs with OQ-C-057-1, which asks whether the rule is intended at all | No — default is: draws a track | Owner |
| OQ-C-057-8 | **`md`'s height is the build's pick, not a measurement.** The note asks for "one inbetween" and does not size it; no Figma symbol draws it. The build uses **8** — the midpoint of the two designed heights that is also a value the program already spends (`space-element-gap`) — rather than the arithmetic 9. Confirm, or draw it | No — default proposed | Owner |
| OQ-C-057-6 | **`aligned` vs the program's `align`.** C-024 SparkBarChart and C-043 MetaChip both spell this concept `align`; this row's Figma axis is `aligned`, and three contracts already cite it that way. Deliberately **not** renamed this run — it is a consistency question, not a placeholder shipping into code (registry rule 6 distinguishes the two) — but the program should pick one spelling before the build phase generates signatures | No | Owner |
