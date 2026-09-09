# 04 — Implementation Readiness Review (notes)


> **Superseded as a decision source:** every ruling below was promoted into
> [DECISIONS.md](DECISIONS.md) on 2026-08-31. This doc remains as the *evidence record* for
> those rulings; "PROPOSED" language below is historical. DECISIONS.md wins on any conflict.

**Date:** 2026-08-31. A gap/feasibility pass over this suite requested before `/build-spec-draft
notes`. Verdict up front: **the analysis is sound and the locked decisions hold; nothing here is
technically infeasible.** What blocks the spec is a handful of open product questions — each is
answered below with a **PROPOSED** ruling grounded in codebase evidence, awaiting user
confirmation.

---

## 1. Proposed answers to the open questions

### N2 — `memberId` or `userId`? → **CONFIRMED 2026-08-31: the leader's account (`userId`)**

User-stated critical requirement: *"Notes are saved to the group leader's account."* The
dual-family evidence below stands as the growth path for a later member surface.

This turned out not to be a decision at all. The server already runs **two parallel route
families over one service**:

- `/api/member/notes` behind `requireMemberAuth` → `req.member.id` (`routes/notes.ts:293`)
- `/api/notes` behind `requireAuth` → `req.user.id` (`routes/notes.ts:1193`)

both delegating to `notes.service.ts:getNotes()`, which takes either owner
(`notes.service.ts:389-407`). The middleware injects the owner; the service is owner-agnostic.

The consumer side is equally settled by evidence: the iPhone app authenticates **only** with a
`connect.sid` session cookie from Google OAuth (`iphone/MakeReady/State/API/APIClient.swift:65-105`)
— there is no phone/member login anywhere in `/iphone`. So:

- **iPhone notes surface (v1) = leaders = `/api/notes` = `userId`.**
- **Member notes surface = the web client = `/api/member/notes` = `memberId`**, whenever it lands.

Nothing changes in the schema; nothing forks in the service.

### N-scope — leader-first? → **CONFIRMED (follows from N2's confirmation)**

Follows directly from N2's evidence plus the locked M7/N6 decision (mimic the iPhone UI; web is a
twin). The reference UX is native iOS; the only app that can render it natively is the leader app.
Ship there first, twin it to the member web experience second.

### N3 — is `NoteLink` the folder? → **No folders in v1; the link is the context line**

The Notes list shows a `🗀 Notes` folder line per row ([01](01-video-analysis.md) §2.2). Our
analogue: render the note's **`NoteLink` target** ("Romans — Lesson 3", "Men's Group") in that
slot, and ship exactly one list ("All Notes"). A real folder/notebook concept is deferred — it
would duplicate what `NoteLink` already expresses, and the reference app's folder UI wasn't even
exercised in the recording. Add `MEMO` to `LINK_TYPES` (`notes.service.ts:51`) so a note can
reference an embedded memo; that is the only link-table change v1 needs.

### N4 — type for a free-form note? → **Add `NOTE` to `NOTE_TYPES`**

`type` is a plain string column, deliberately extensible (`schema.prisma:1231`,
`routes/notes.ts:224`). Add `NOTE: 'NOTE'` to `notes.service.ts:41` and default the new surfaces
to it. Zero migration.

### N5 — autosave conflict policy? → **LWW, with a cheap stomp detector**

Confirmed last-writer-wins on `updatedAt`. One personal note contended by at most two devices
(a leader's iPhone and a browser) does not justify merge machinery. One safeguard, nearly free:
the client sends the `updatedAt` it last saw with each PATCH; if the server's row is newer it
still writes (LWW) but flags `{ stomped: true }` in the response so the client can refetch and
tell the user. No locks, no versions.

### N7 — search placement? → **Server-side `q` param**

Pagination already exists (`limit`/`offset`, default 50 — `routes/notes.ts:455-465`), which means
the client never holds the full corpus, which decides it: search must be server-side. Add `q` to
both list endpoints → `content: { contains: q, mode: 'insensitive' }` in the service's where
clause. At the observed scale (hundreds of notes per owner) ILIKE is fine. Future upgrade path
exists in-repo: `server/src/services/embeddings.ts` for semantic search over notes + memo
transcripts — noted, not v1.

---

## 2. Feasibility findings (gaps the suite didn't cover)

| # | Finding | Severity | Ruling |
|---|---|---|---|
| F1 | **Empty-note handling conflicts with the API.** Apple *discards* an empty note on exit — that's why compose-then-back never litters the list. Our `updateNoteSchema` requires `content: min(1)` (`routes/notes.ts:230`) and `createNoteSchema` likewise, so the natural client flow (create on open, autosave as you type) 400s on an empty note. | High | Copy Apple: **create the record lazily on first non-empty content**, and **delete (soft) on exit if content is empty**. No schema change needed. |
| F2 | **List rows need `title`/`preview` without parsing markdown per row.** [03](03-makeready-translation.md) §2.3 said "additive response shaping" but left the mechanism open. Parsing every note's markdown on every list render is waste. | Med | **Denormalize:** derive `title` (first non-empty line, markdown-stripped) and `preview` (second) **at write time** in the service; two new nullable columns, backfillable in one script. |
| F3 | **The web editor engine is an unmade decision.** A GFM-editing surface with live styling, selection toggles, and list behaviors, hand-rolled on `contenteditable`, is a multi-week trap. | High | **Recommend TipTap (ProseMirror) with markdown serialization**, restyled to twin the iOS surface. The twin discipline governs *appearance*; it doesn't require reinventing text editing. Needs a ledger entry — it's the largest unowned choice in the notes build. |
| F4 | **iOS parse/serialize pair.** Parse GFM → attributed runs with Apple's `swift-markdown` (SPM); the serializer (runs → GFM, with literal-character escaping) is custom but small and testable. | Low | Named here so it lands in `06-iphone.md` with round-trip tests (`parse(serialize(x)) == x`). |
| F5 | **Offline edits.** The iPhone app is offline-capable by design (disk-cached AppState). An autosave with no network must queue and flush on reconnect — and then N5's stomp detector matters most, since queued writes are stale by definition. | Med | Queue-and-flush per note (latest content wins locally; one PATCH per note on flush), stomp flag honored on flush. |
| F6 | **Checklist state is content, not metadata.** Tapping a checkbox in *view* mode rewrites `- [ ]` ↔ `- [x]` in `content` — i.e. viewing a note can trigger the autosave path. Harmless, but only if F1's lazy-create rule is in place and the PATCH is the same debounced channel. | Low | Note for both editor phases. |
| F8 | **Dictation (critical req #5) is free — protect it.** The system keyboard's mic key dictates into any `UITextView` with zero code. The only ways to lose it are a custom `inputView` (we use `inputAccessoryView` only — safe) or a non-standard keyboard type. Add one manual test: dictate into a note, confirm text lands at the caret with the format strip docked. | Low | No build; one test. |
| F9 | **No-length-limit (critical req #4) verified.** `content` = Postgres `Text`; no zod max; JSON body limit 10 MB (`index.ts:219`). Requirement flips to the editor: long-document smoothness (TextKit 2 handles this; the web twin must virtualize nothing prematurely). | Low | No server change; perf note for both editor phases. |
| F7 | **Doc numbering collision.** This suite's `01–04` are analysis docs; `/build-spec-draft` owns `01–09` at the feature root. | Med | Move analysis to `docs/features/notes/analysis/` before running the draft (same for memo). |

---

## 3. What `/build-spec-draft notes` still has to do

The analysis suite is the *input*. The draft conversation still owes: the endpoint-by-endpoint
contract table (03-data-and-api), the exact `AppState`/Actions/Route additions for the iPhone
list + editor (06-iphone), the format-strip component inventory against the house design system,
gate commands (08-testing), and the ledger (09). With §1 confirmed, nothing blocks starting it.
