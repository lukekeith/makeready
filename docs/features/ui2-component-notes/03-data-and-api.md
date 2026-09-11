# 03 — Data & API (the shared contract)

No Prisma schema change. The contract here is **two file formats** and **four HTTP shapes**,
plus the derivation rule two skills implement independently.

## 1. File formats

### 1.1 Note file

**Path:** `docs/ui2/design-system/components/notes/C-###.md` (components) ·
`docs/ui2/screens/notes/<screen-id>.md` (screens).

Created on first append. The directories are committed with a `README.md` explaining the
format so an empty dir is never mistaken for a missing feature.

```markdown
# C-052 DayChip — notes

Append-only, oldest first. Newer notes supersede older ones where they conflict
(docs/features/ui2-component-notes/01-architecture.md D3). Written by the capture
browser's Component tab; hand-edit only to fix a typo.

## 2026-09-11T14:32:05.412Z

The active chip stays pinned to the leading edge while the rail scrolls, the way
@C-019 pins its selected tab. On @home-dashboard there is no rail, so this does
not apply there.

## 2026-09-12T09:04:11.006Z

Supersedes the pin behavior above: the rail scrolls freely and the active chip
moves with it.
```

**Binding rules.**

| Rule | Value |
|---|---|
| Heading level | `##` exactly. `#` is the file title; a `##` at the top level of the body is always a note boundary. |
| Note id / sort key | The heading text: an **ISO 8601 UTC instant with milliseconds** (`YYYY-MM-DDTHH:MM:SS.sssZ`). It is the note's identity, its ordering key, and what D3's "newer" means. |
| Order in file | **Oldest first** (append is a pure file append). The UI renders newest first. |
| Body | Everything between one `##` heading and the next, trimmed. Plain text; blank lines preserved. Markdown is **not** rendered — a note is read as written. |
| Mention token | `@C-###` or `@<screen-id>`, matched as `@([A-Za-z0-9][A-Za-z0-9-]*)` and accepted only when the captured id resolves against the mention index (§2.3). An unresolvable `@word` is literal text, not a broken link. |
| Encoding | UTF-8, `\n` line endings, file always ends with exactly one newline. |
| Duplicate timestamps | The appender checks the last heading in the file and, on collision, advances by 1ms. Two notes never share an id. |

**Parse failure is per-file and non-fatal.** A file whose content does not match this shape
yields zero notes plus a `parseError` string on the API response; it never 500s and never
affects another target.

### 1.2 Screen element map

**Path:** `docs/ui2/screens/assets/<snapshot-stem>.elements.json` — sibling of the PNG it
describes, so a multi-frame screen gets one map per frame (`invite-home.elements.json`,
`invite-home-linked.elements.json`). This matches the existing `.elements.json` convention the
iOS harness already uses beside its renders.

```json
{
  "screen": "home-dashboard",
  "snapshot": "home-dashboard.png",
  "node": "3622:5487",
  "size": { "w": 440, "h": 2730 },
  "generatedBy": "backfill@2026-09-11",
  "elements": [
    {
      "ref": "C-023",
      "name": "KpiCard",
      "instance": "3673:12248",
      "x": 0.0364, "y": 0.1205, "w": 0.4409, "h": 0.1317
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `screen` | Screen id (README table key, D8 of the UI2 program). |
| `snapshot` | The PNG this map describes; the browser pairs them by filename, this field is the assertion. |
| `node` | Figma node id of the frame, for provenance and re-run diffing. |
| `size` | The exported image's own coordinate space in points — **read from Figma, never guessed**. Used only to sanity-check aspect ratio against the PNG. **Corrected 2026-09-10 (audit pass 1):** the example above originally read `440×2126`, which is not home-dashboard's frame — the spec records `440×2730` (`docs/ui2/screens/home-dashboard.md` §1) and the PNG on disk is 331×2048 (ratio 0.1616 vs 0.1612, a 0.3% drift that passes). The original number would have diverged 28% and the guard below would have discarded the whole map. Composite (multi-frame) exports are 09 §G-5. |
| `generatedBy` | `ui2-screen@<date>` (authoritative) or `backfill@<date>` (migrated, D5). |
| `elements[].ref` | The registry id this instance resolved to. **Required** — an instance with no confident ref is omitted from the file entirely (D5). |
| `elements[].name` | The registry name at authoring time. Display **falls back** to this only when `ref` no longer resolves; the live registry name wins (R2). |
| `elements[].instance` | The Figma node id of this instance. Provenance; lets a re-spec diff the map. |
| `elements[].x/y/w/h` | Rect as fractions of the frame, `0…1`, same convention as the iOS harness. |

**One entry per instance.** Fourteen `C-052` chips produce fourteen entries with the same
`ref`. Nesting is expressed by containment, not by a parent field — the hit test derives depth
from area (D8), and authoring order puts inner elements later.

**Aspect-ratio guard.** Before use, the server compares `size.w / size.h` against the PNG's
`width / height`; a divergence over 1% discards the map, exactly as `ui2ElementMap()` does
today. A stale map is worse than none — it would attribute notes to the wrong component.

## 2. Endpoints

All under the capture backend (`capture/server.mjs`, port 5951), proxied by Vite at 5950.
No auth — capture is a local dev tool with no auth layer.

### 2.1 `GET /api/ui2/notes`

| | |
|---|---|
| Query | `target` — a `C-###` or a screen id. Required. |
| 200 | `{ target, kind: "component" \| "screen", file, exists, notes: [ { id, at, body, refs } ], parseError? }` |
| 404 | Target resolves to neither a registry row nor a README screen row. |

- `notes` is ordered **newest first**.
- `id` and `at` are both the ISO instant (`id` for keys, `at` for display).
- `refs` is the resolved mention list: `[{ token, kind, id, name }]`, mentions that do not
  resolve are absent from `refs` and stay literal in `body`.
- `exists: false` with `notes: []` when no file has been written yet — not an error.

### 2.2 `POST /api/ui2/notes`

| | |
|---|---|
| Body | `{ target, body, after? }` — `after` is the id of the newest note this client had when it opened the composer, used for the 409 check below ***(audit default 2026-09-10, 09 §G-7)***. |
| 200 | `{ ok: true, note: { id, at, body, refs }, file }` |
| 400 | `body` empty after trim, or over 8000 characters. |
| 404 | Unknown target. |
| 409 | The file's last note id differs from the `after` the request carried — someone appended between this client's read and its write. Omitting `after` skips the check. ***(audit default 2026-09-10 — the original row defined a 409 with no detection mechanism and no field to detect it with; see 09 §G-7. Veto-able at the decisions gate: the alternative is dropping the 409 entirely.)*** |

- Creates the file with its title + preamble when absent, then appends a `##` heading (§1.1)
  and the trimmed body.
- **Append is atomic**: write to a temp file in the same directory, then `rename`. A crash
  mid-write cannot leave a half-written note.
- Non-production only, guarded by the same `!isProduction` check the fixture-write route uses.

### 2.3 `GET /api/ui2/mentions`

| | |
|---|---|
| 200 | `{ items: [ { kind: "component" \| "screen", id, name, section, hasNotes } ] }` |

The union of every registry row and every README screen row, sorted components-then-screens by
id. This is the `@` typeahead's whole data source; the client filters it locally (**98 rows —
73 registry ids + 25 README screen rows, verified in code (2026-09-10)** — so a request per
keystroke would be waste).

### 2.4 `elements` on `GET /api/ui2/screen-detail`

Each entry in `variants[]` gains:

```json
"elements": { "size": { "w": 440, "h": 2126 }, "generatedBy": "backfill@2026-09-11",
              "elements": [ { "ref": "C-023", "name": "KpiCard", "x": 0, "y": 0, "w": 0, "h": 0 } ] }
```

`null` when no map exists, is unparseable, or fails the aspect-ratio guard (§1.2) — the client
treats all three identically and renders no boxes. Every existing key on this route keeps its
current meaning.

Each element's `ref` is additionally resolved against the registry so the client can label
without a second fetch: entries gain `resolved: { name, specced, built, hasSnapshot }`, or
`resolved: null` for a ref that no longer exists in the registry.

## 3. Effective requirements (the derivation both skills implement)

Given a component, its **effective requirement set** is the contract plus its notes, reduced
by D3/D13:

1. Start from the normative spec: the contract file (or the defining screen spec's §4), the
   registry row, and the frozen Figma snapshot.
2. Read the target's notes **oldest → newest**. Read each dependency's notes too (a note on
   `C-021` binds every component that renders a `C-021`).
3. Apply each note as a set of statements about named properties (geometry, color, state,
   prop, behavior, copy, interaction).
4. **A later statement about the same property replaces an earlier one** — from another note,
   or from the spec. Supersession is **per-property**: an older note's other statements stay in
   force (R13).
5. Emit two artifacts:
   - the **effective set** — every requirement with its source (`spec` | `note <id>`), and
   - the **drift list** — every requirement where a note overrode the spec, with both values.

The drift list is reported, never auto-applied to `docs/ui2` (D3). It is the owner's signal
that a spec doc or a Figma frame has fallen behind.

**Consequence for the pixel diff.** `/ui2-component-build` phase 6 and `/ui2-component-update`
both diff the built render against the frozen Figma snapshot. A note-driven override makes
that diff *correctly* non-zero. Both skills must classify a difference that appears in the
drift list as **expected** and report it separately from unexplained divergence; treating it as
a failure would drive the build to undo the owner's own instruction.

## 4. Existing contracts consumed unchanged

`GET /api/ui2/screens` · `GET /api/ui2/screen-detail` (other keys) · `GET /api/ui2/detail` ·
`GET /api/ui2/version/:vid` · `POST /api/ui2/refresh` · comment CRUD routes and the
`makeready-capture` MCP comment tools. None change shape; the comment channel is deliberately
independent of notes (D2).
