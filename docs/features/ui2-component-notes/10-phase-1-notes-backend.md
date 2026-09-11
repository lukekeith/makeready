# Phase 1 — Notes storage + routes  ·  app: capture (backend)

> Part of docs/features/ui2-component-notes/. Preconditions: none — first phase.
> The two file formats in [03](03-data-and-api.md) §1 are the contract every later phase and both
> skills code against; this phase implements the note half of it.

## Goal

`docs/ui2/**/notes/<target>.md` becomes a real, parseable, appendable store with one
implementation behind it — a module the capture server calls in-process and both skills call as a
CLI. At the end, a note can be written and read back over HTTP, the mention index answers, and
none of it depends on the UI.

## Companion skills

None — this is capture-internal Node. Follow the existing module style in `capture/lib/`
(`ui2-fixture.mjs` is the closest sibling: pure functions + one writer that owns a repo file).

## Tasks (in order)

- [x] 1.1 `capture/lib/ui2-notes.mjs` — `notesPath` / `parseNotes` / `formatNote` / `readNotes` /
      `appendNote` / `extractMentions` per [07](07-capture.md) §2, exactly the format in
      [03](03-data-and-api.md) §1.1 · tests: N-1…N-8 in `capture/test/ui2-notes.test.mjs`
- [x] 1.2 The `read` CLI on the same module (`node capture/lib/ui2-notes.mjs read <target>` → JSON,
      exit 2 on unknown target) — 07 §2, resolves 09 §X-2 · tests: R-9
- [x] 1.3 The two notes directories + their `README.md` preamble files
      (`docs/ui2/design-system/components/notes/`, `docs/ui2/screens/notes/`) — 03 §1.1
- [x] 1.4 `GET /api/ui2/notes` + `POST /api/ui2/notes` + `GET /api/ui2/mentions` in
      `capture/server.mjs`'s UI 2.0 section — 03 §2.1–2.3, 07 §3. POST inside the existing
      `if (!isProduction)` block (`server.mjs:1635`) · tests: R-1…R-4, R-8
- [x] 1.5 `fetchUi2Notes` / `postUi2Note` / `fetchUi2Mentions` in `capture/src/api.js`, in the
      style of the existing UI 2.0 fetchers (`src/api.js:270-362`) — 07 §3

## Phase gates

- [x] `cd capture && npm test` — **84 tests, 83 pass, 1 fail**; the fail is the pre-existing
      `parseContract handles the axis-shaped matrix` (baseline 73/72/1, so +11 tests, all green)
- [x] `curl -s localhost:5951/api/ui2/mentions -o /dev/null -w '%{http_code}'` → **200**

## Verification checklist

- [x] `POST` then `GET` round-trips: the note comes back newest-first with its mentions resolved
- [x] The file on disk matches 03 §1.1 byte-for-byte — `##` ISO heading, oldest first, one
      trailing newline
- [x] Two appends inside one millisecond produce ids 1ms apart, and neither is lost
- [x] A hand-corrupted note file yields `parseError` + `notes: []` and does not affect another
      target or 500 the route
- [x] `node capture/lib/ui2-notes.mjs read C-052` prints the same JSON the route returns, with the
      capture server stopped
- [x] Contract parity: the response keys are exactly 03 §2.1–2.3's, no extras, no renames

## VERIFIED

✅ **2026-09-10**

**Gates.** `npm test` → 84 tests / 83 pass / 1 fail, the fail being the pre-existing
`parseContract handles the axis-shaped matrix` (baseline was 73/72/1; this phase adds 11 tests,
all passing). `GET /api/ui2/mentions` → 200.

**Walk.** All five route checks run live against the restarted capture server on :5951:

- **R-1** `GET notes?target=C-052` with no file → 200 `exists:false, notes:[], parseError:null`.
- **R-2** POST → GET round-trip: the note comes back newest-first with `refs` resolved to
  `C-019 TopNav` and `home-dashboard Home (leader dashboard)`; `@C-999` resolved to nothing and
  correctly stayed literal text in the body rather than becoming a broken link.
- **R-3** empty body → 400 · unknown target → 404 on both POST and GET.
- **R-4** `GET mentions` → **98 items = 73 components + 25 screens**, matching 03 §2.3's count
  exactly; `hasNotes` flipped to true for C-052 the moment its file existed and back after.
- **R-8** a stale `after` → 409 with no write; the correct `after` → 200.
- **On-disk format**: the file rendered byte-for-byte as 03 §1.1's example, title
  `# C-052 DayChip — notes` included (the registry name comes from the route, which is why
  `appendNote` takes an optional title).
- **CLI**: `node capture/lib/ui2-notes.mjs read C-052` prints the same JSON the module returns,
  with no server and no database (09 §X-2).

**Note on verification data:** the C-052 notes written during this walk were **deleted** before
signing. A note is normative build input — leaving a fabricated one on disk would make
`/ui2-component-build` honour a requirement nobody asked for.

Commit: see the phase commit below.
