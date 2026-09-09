# shared-edit-field — Single-field edit screen (PATTERN)

Platform: iphone · Status: specced · Specced: 2026-09-01 · Re-specced: 2026-09-02 (source
re-pointed to section `3875:8253` per owner; **diff result: zero contract drift** — the new
section's frames are node-for-node structurally identical to the 2026-09-01 source; this
pass adds the group-field instantiation annex, the age-range option semantics, and OQ-6)

**This is a pattern spec, not one screen.** Owner (2026-09-01): tapping an EditableFieldRow
(C-042) — displayed on multiple views — opens a page that **edits exactly that one field**,
and the provided edit-screens set shows the pattern and the scope of what is editable.
Every concrete edit screen (group name, group description, visibility, member phone, program
title, …) is an instantiation of this template; a build suite may not invent a multi-field
form where this pattern applies.

## 1. Normative source

- **Primary (2026-09-02):** https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3875-8253
  — section `3875:8253` "Edit screens" (6 frames), file `nVva9a2WvYmcWQo6zlHupO`, owner-designated.
  Frames: Group name (no-changes `3771:6789` / ready-to-save `3771:6846`), Group
  description `3770:6408`, Group visibility `3770:6456`, Group member directory access
  `3770:6572`, Group age range `3770:6646`.
- Frozen snapshots: `assets/edit-field-group-fields.png` (section `3875:8253`, captured
  2026-09-02) + `assets/edit-field-overview.png` (2026-09-01, still valid for the frames
  below).
- **Retained from section `3860:8218`** (verified still present and unchanged 2026-09-02):
  Edit title getting-suggestions `3860:8322` and with-suggestions `3860:8334` — the two
  C-051 state frames, which the new section does not duplicate. (`3860:8218` otherwise
  duplicates the six frames above node-for-node; where the two sections ever diverge,
  `3875:8253` wins.)
- Component sets verified on the sheet (D9): Text input `3524:30063`+Multi `3547:31813…`,
  Radio `3770:6532` (+glyph `3770:6508`), Page buton `3517:29389` (color Green/Red) and
  `3547:31761`, Link button `3525:30224`, Suggestion `3526:30792`, Donut `3526:30644`,
  Toggle field `3547:31612`.

**Deviations (closed list):**
1. All copy, values, and sample field names are per-instance content — each concrete edit
   screen supplies its own title, description text, and inputs.
2. The status bar is the iOS system status bar.
3. The set's frames are group/program fields; member fields (phone, email, …) instantiate
   the same template — their extra verification steps are NOT designed yet (OQ-2).
4. The directory-access frame's page description is a copy-paste artifact (it repeats the
   visibility frame's "Visibility determines who is able to view the group") — the built
   instantiation carries its own correct copy; the annex marks it `copy TBD (owner)`.
5. Per-frame Save-button colors are sample states (e.g. the age-range frame shows
   affirmative green with no visible change) — the §3 clean/dirty rule governs, not the
   frame's sampled state.

Anything else that differs from the source is a defect.

## 2. Layout contract

Pushed page: status bar → **PageHeader (C-040)** — back + centered title = the field's name
("Group name", "Visibility", …), no right icons (measured 2026-09-02: the frames use
`style=Two icons` with `showIcons=false`, not `style=Default`) → content inset
`space-page-margin` (16), content column gap `space-section-gap` (32):

1. **Page description** — SF Pro Regular 14/20 `text/secondary`, 16pt top inset: one short
   paragraph explaining the field (per-instance copy).
2. **Input block** (32pt below description), one of the §4 input arrangements:
   - `text-single` — FieldGroup (C-046): bold 14 label + 44pt TextInput.
   - `text-multi` — FieldGroup with 88pt multiline TextInput.
   - `radio` — RadioOptionRow (C-047) stack; rows 100pt with description, 54pt without.
   - `radio+range` — radio stack + a 2-up row of compact FieldGroups (196pt wide, 16pt
     gutter), 32pt below the radio stack. Measured on `3770:6646`: 5 title-only rows
     (54pt: 16pt vertical padding, title↔glyph 16 gap, 22pt glyph) + "Minimum age" /
     "Maximum age" single-line FieldGroups. The min/max row is present in the frame's only
     designed state (with "Any age" selected) — its enable/gating rule is OQ-6.
   - `toggle` — Toggle field (designed on the sheet, unconsumed in the 8 frames; available
     for boolean fields).
3. **AI Suggestions block (C-051)** — present only on fields the design gives it to
   (name/description/title class): 32pt below the input.
4. **PageActionButton (C-048)** — "Save", 408×38, bottom of content with 32pt clearance.

### 2b. Designed instantiations — group fields (annex, 2026-09-02)

The six frames of `3875:8253` are the **normative instantiations for the group-home field
edits** — `groups-detail` cites these rows rather than redesigning them. (Owner, 2026-09-02:
this pattern is how ALL fields are edited when tapped on pages like group home, program
home, and group member home.)

| Field | Title | Arrangement | Content (exact, from the frames) | Entity mapping (§5) |
|---|---|---|---|---|
| Group name | "Group name" | `text-single` + C-051 | Description: "The group name is the primary title for your group that will be surfaced anytime the group is displayed in a MakeReady app". AI prompt: "If you need help coming up with a name for your group, MakeReady AI can analyze your content and provide suggestions." | `Group.name` |
| Group description | "Description" | `text-multi` + C-051 | Description: "The group description is used to help others understand the purpose of your group at a glance." AI prompt: "If you need help writing a description for your group, MakeReady AI can analyze your content and provide suggestions." | `Group.description` |
| Visibility | "Visibility" | `radio` (2 options, with descriptions) | "Visibility determines who is able to view the group" · **Private** — "Only active members of the group can view information about the group, organization, and group leader." · **Public** — "Anyone can search and view information about the group and the group leader." | `Group.isPrivate` |
| Member directory access | "Member directory access" | `radio` (3 options, with descriptions) | Page description: copy TBD (owner — deviation 4). **Allowed** — "All members are able to view the full membership directory with contact information for every member" · **Names only** — "Members are able to see who is in the group, but they are not able to view any contact information" · **Not allowed** — "Members are not able to view any information about members in the group" | tri-state — API-GAP (§5) |
| Age range | "Age range" | `radio+range` | Description: "If an age range is specified, then every member who joins must fall within the specified range." Options: **Any age** · **18 - 25** · **26 - 35** · **36 - 50** · **Custom range**; min/max FieldGroups "Minimum age" / "Maximum age" (gating: OQ-6) | `Group.ageRangeMin` / `ageRangeMax` (Any age = both null; presets are client-side sugar over the same two columns) |

## 3. Behavior contract

**States (closed list):**
- `clean` — as-loaded value; Save renders **disabled** (neutral: 1px `layout/border`,
  label `text/secondary`). Frame: "Group name - no changes".
- `dirty` — value differs from loaded; Save renders **enabled-affirmative** (1px `green`
  border, `green` label). Frame: "Group name - ready to save".
- `saving` — proposed default (undesigned): Save disabled with activity indicator; OQ-3.
- `save-failed` — proposed default (undesigned): inline error above the button, value
  preserved; OQ-3.
- Radio screens: selecting a different option = dirty; exactly one option selected at all
  times (single-select).
- `radio+range` (age range): **proposed default model (OQ-6, undesigned beyond the single
  frame):** the min/max FieldGroups always render; selecting a preset fills them with that
  preset's bounds (read-along), "Any age" clears them, and editing either field directly
  moves the selection to "Custom range". Whatever the ruling, min ≤ max validation and the
  dirty rule (any effective bounds change) apply.

**Interactions:**
- Back (C-040) discards unsaved changes — no confirm dialog is designed; proposed default:
  discard silently when `clean`, and OQ-3 covers whether dirty-back warns.
- Save (enabled) commits the single field via §5 and pops back to the presenting screen,
  which reflects the new value.
- AI Suggestions (C-051) — closed state machine per the frames:
  1. `prompt` — description copy + LinkButton (C-049) "AI suggestions": tap starts
     generation.
  2. `generating` — 24pt Donut spinner + "Generating suggestions" (Semibold 14
     `text/secondary`).
  3. `list` — "AI Suggestions" header + LinkButton "Try again" + up to 3 SuggestionRow
     (C-050) items separated by hairlines; tapping a row's Add glyph fills the input with
     that suggestion (→ `dirty`); "Try again" regenerates.

**Motion:** standard push/pop; no bespoke motion designed.

## 4. Components

Closed list rendered: **C-040 PageHeader** · **C-045 TextInput** · **C-046 FieldGroup** ·
**C-047 RadioOptionRow** · **C-048 PageActionButton** · **C-049 LinkButton** · **C-050
SuggestionRow** · **C-051 AISuggestionsBlock** (+ the sheet's Toggle field, registered as a
designed variant of the pattern, unminted until a screen consumes it).

### C-045 TextInput
**Contract relocated 2026-09-03** → `../design-system/components/C-045-text-input.md`
(full 6-symbol matrix, exact geometry, the focus-overlay reading, error/disabled
proposals). This pattern consumes all six designed state×lines combinations; citation
correction: `3547:31813` is a symbol inside set `3524:30063`, not a second set.

### C-046 FieldGroup (new)
Label + input stack — set `3524:30092` fully enumerated (2026-09-01): **`Field {Text 70pt,
Multiline Text 114pt} × style {Default, Focus}`** — four designed variants. Label SF Pro
Bold 14 white (unchanged across variants), 12pt gap, C-045 beneath; `style=Focus` = the
inner C-045 in its `Has value + Focus` state (white border + 2×24 `color-accent` caret).
Widths: 408 full or 196 compact (2-up range rows, width-driven not a variant). Props:
`label`, plus C-045 pass-through (`lines`, `focused`).

### C-047 RadioOptionRow (new)
Sheet set `3770:6532`: 16pt vertical padding; title SF Pro Regular 14/20 white (single
line, ellipsized) + optional description SF Pro Regular 14/20 `text/secondary` (8 gap);
trailing 22pt radio glyph — **designed states `Default` / `Selected`** (glyph set
`3770:6508`). Row height is content-driven (54pt title-only, 100pt with description) —
not separate variants. Props: `title`, `description?`, `selected`, `onSelect`.

### C-048 PageActionButton (new)
Full-width 38pt bordered pill, r8, centered label SF Pro Text Regular 12/20 ls −0.24.
**Designed states:** `disabled` (1px `layout/border` + `text/secondary` label — sheet
`3547:31761`) · `affirmative` (1px + label `green` — sheet `3517:29390`) · `destructive`
(1px + label `Red/100` — sheet `3517:29388`, **designed-unconsumed**, reserved for
delete/remove actions). Sheet hygiene: the disabled and colored looks live as two separate
Figma components ("Page buton" ×2) — one code component with three states (flagged in
tokens hygiene notes). 2026-09-02/03 addendum: the color set also designs `White`
(FILLED white, black 12pt label — first consumed by C-066 ActionMenuOverlay "Done") and
`Muted` (designed-unconsumed). Props: `label`, `state`, `action`.

### C-049 LinkButton (new)
Inline text link (sheet `3525:30224`, single `style=Default`): SF Pro Semibold 14/24
`color-accent` with a 0.5px `color-accent` bottom border. Consumed here as "AI
suggestions" / "Try again". **Also retroactively identified as home-dashboard's "Link
button" instance** ("Jump to today") — but that instance renders in `text/secondary`, not
purple: instance override vs component color needs one ruling (OQ-4). Props: `label`,
`action`.

### C-050 SuggestionRow (new)
Sheet `3526:30792` (single Default variant): 56pt row — suggestion text SF Pro Regular
14/24 white (flex) + C-021 GlyphButton `add` trailing; hairline separators between rows.
Props: `title`, `onAdd`.

### C-051 AISuggestionsBlock (new)
The composite AI block with the §3 three-state machine (`prompt` / `generating` / `list`).
Composes: description copy, C-049 (start/retry), the 24pt Donut spinner (sheet
`3526:30644`, single variant — registered inside this row, extract later if another
consumer appears), C-050 ×≤3. Props: `state`, `promptCopy`, `suggestions`, `onGenerate`,
`onPick`.

### Amendments (dated 2026-09-01)
- **C-042 EditableFieldRow** — behavior contract completed: tap opens the `shared-edit-field`
  instantiation for that field (resolves OQ-members-profile-1).
- **C-020 SectionHeader** — the `text-link` accessory is C-049 LinkButton (pending OQ-4's
  color ruling).

## 5. Data & API

Each instantiation PATCHes its **one field** on the owning entity:

| Field family | Endpoint | Status |
|---|---|---|
| Group fields (name, description, visibility, age range) | `PATCH /api/groups/...` — group update route (verified family: `POST /api/groups` etc.; exact PATCH shape audited by the build suite). Model mapping verified 2026-09-02 (`server/prisma/schema.prisma` Group): `name`, `description`, `isPrivate`, `ageRangeMin`/`ageRangeMax` all exist | ✅ exists |
| Member directory access (tri-state: Allowed / Names only / Not allowed) | — | **API-GAP:** `Group.memberDirectoryEnabled` is a **Boolean**; the designed field has three options — schema migration to an enum + PATCH support required. Also the known zod bug stripping `memberDirectory` on PATCH (`parity-edit-group` memory) must die in the same suite |
| Program fields (title, description) | `PATCH /api/programs/{id}` family (verified) | ✅ exists |
| Member fields (phone, email, birthday, gender, …) | `PATCH /api/members/{memberId}` (verified) + phone verification via Twilio (`/api/verification/*`, verified) | ✅ exists for simple fields; **verification-step UX for phone/email is undesigned** (OQ-2) and email verification is an API-GAP (members-profile OQ-3) |
| AI suggestions | — | **API-GAP: a field-suggestion endpoint** (input: entity + field + context; output: ≤3 strings). The server already integrates Claude AI (tagging/alt text) — this is a new route on that integration |

## 6. Connections

- **Entry: pattern-wide** — every C-042 EditableFieldRow tap anywhere (members-profile's 8
  fields today; groups-detail and program settings when those frames arrive) pushes the
  field's instantiation of this pattern.
- **Exit:** Save or back → pop to the presenting screen.
- No overlays.

## 7. Legacy mapping

| Legacy element | Disposition |
|---|---|
| `editGroupContent` inline form (leading SlideStack pane — `parity-edit-group` memory: whole-group form with live bindings) | carried, decomposed: one legacy multi-field form becomes N single-field edit screens |
| Legacy program settings editors (title/description fields in `Pages/Manage/Program/*`) | carried into instantiations of this pattern |
| Member profile editing + phone verification flows | carried; verification steps pending design (OQ-2) |
| `Route.swift` editor cases for the above | superseded by pattern instantiations; enumerated per-case in gap-analysis sweep 1 |

## 8. Open questions

| # | Question | Blocking? | Decides |
|---|---|---|---|
| OQ-shared-edit-field-1 | The editable-scope list: the frames cover group/program fields; confirm the full closed list of fields that get an edit screen (members-profile's 8 field rows are assumed IN). **Owner confirmed 2026-09-02:** the pattern governs field taps on group home, program home, and group member home — the per-screen field lists still land as each presenting screen is specced (group fields: §2b annex) | No — each instantiation is confirmed as its presenting screen is specced | Owner |
| OQ-shared-edit-field-2 | Phone/email edits need verification steps (OTP) — undesigned; also whether changing a verified value resets its Verified badge | No for the pattern; gates those two instantiations | Owner (frames or ruling) |
| OQ-shared-edit-field-3 | Undesigned states: `saving`, `save-failed`, and dirty-back (warn vs silent discard) — proposed defaults in §3 | No — proposed defaults stand until ruled | Owner |
| OQ-shared-edit-field-4 | LinkButton color: the component is `color-accent` purple w/ underline; home-dashboard's "Jump to today" instance renders `text/secondary` — one ruling (variant, or home is an override) | No | Owner |
| OQ-shared-edit-field-5 | AI-suggestions field scope: designed for name/description/title fields — closed list of which fields ship with the block | No — per-instantiation confirmation | Owner |
| OQ-shared-edit-field-6 | `radio+range` min/max gating: the only designed state shows the min/max fields alongside a selected preset ("Any age", values 18/24). Proposed default in §3: always visible, presets fill them, direct edits select "Custom range". Ratify or supply state frames | No — proposed default stands | Owner |
