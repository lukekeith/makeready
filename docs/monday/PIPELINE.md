# Monday Ticket Resolution Pipeline

The full lifecycle for monday.com tickets, from board sweep to closed-with-evidence. Monday is the source of truth for *ticket state*; this directory is the source of truth for *everything an LLM needs to work the ticket* — verbatim reports, screenshot descriptions, verdicts, root causes, and (critically) the **affected-areas contract** that scopes any fix.

## The stages

```
/monday-review                /monday-ticket [ref]              /monday-resolve <ref> <resolution>
  board-wide sweep      →       single-ticket deep dive    →      implement + verify + close
  verdicts vs. main             screenshots + code mapping        gated on confirmed affected areas
  writes triage file            writes/confirms the dossier       updates monday + dossier + triage

/monday-list — read-only status board at any time: live monday state merged with dossiers;
  rich context for deep-dived tickets, queue order for the rest, staleness flags.
```

## The deep-dive queue (shared by /monday-list and no-arg /monday-ticket)

`/monday-ticket` with no argument takes the next ticket from this queue; `/monday-list` displays it. Ordering over open tickets:

1. **Bucket 1 — never dived:** `deep_dive: none` (or no dossier at all).
2. **Bucket 2 — stale dives:** `deep_dive` set, but monday has updates newer than that date.
3. Within a bucket: board Priority (High → Medium → Low → unset), then oldest `created_at` first.

Tickets whose dossier status is `in-progress`, `resolved-pending-verify`, or `closed` are not in the queue.

- **`/monday-review`** — evidence-backed verdict for every open ticket (VERIFIED FIXED / LIKELY FIXED / OUTSTANDING / NEEDS CLARIFICATION). Creates dossier stubs for tickets that lack one and syncs `verdict`/`last_review` on existing dossiers. May propose closures for VERIFIED FIXED tickets (confirmation-gated). Affected areas from review are at most `provisional` — review works from ticket text, not screenshots.
- **`/monday-ticket`** — reads the FULL ticket including screenshot attachments, maps the report to the exact screens/components/files, and writes the dossier with `affected_areas: confirmed`. This is the only stage allowed to set `confirmed`, because only it looks at the screenshots that disambiguate which screen the reporter meant.
- **`/monday-resolve`** — takes the user's described solution and implements it, **hard-gated** on the dossier existing with `affected_areas: confirmed`. Refuses to touch files outside the in-scope list without explicit user sign-off. On success it updates the monday ticket (evidence comment + status) and the local dossier/triage notes.

## The store

```
docs/monday/
  PIPELINE.md              ← this file (the contract all three skills follow)
  README.md                ← index + work-item analysis (CF-x / UX-x / FR-x)
  tickets/
    TEMPLATE.md            ← dossier template (copy for new tickets)
    <item_id>.md           ← one dossier per ticket (e.g. 12268478769.md)
  triage-YYYY-MM-DD.md     ← dated board-sweep reports from /monday-review
  tickets.md               ← 2026-07-05 raw inventory (historical; dossiers supersede it)
  code-fixes.md, ui-ux.md, feature-requests.md  ← 2026-07-05 work-item analysis
```

## Dossier frontmatter (machine-checked by /monday-resolve)

```yaml
ticket: 12268478769            # monday item id — must match filename
title: add bible verse unclear
board: 18413909869
url: https://scotts-team283817.monday.com/boards/18413909869/pulses/12268478769
created: 2026-06-13
reporter: Scott Stickane
status: open                   # open | in-progress | resolved-pending-verify | closed
verdict: LIKELY FIXED          # latest verdict + its date lives in Triage history
last_review: 2026-07-19        # last /monday-review that touched this ticket
deep_dive: none                # none | YYYY-MM-DD of last /monday-ticket run
affected_areas: provisional    # none | provisional | confirmed
type: none                     # none | UI/UX | Data & Lifecycle | Authorization | Media | Infrastructure | Unknown — PRIMARY AREA (set by /monday-ticket; mirrors monday Type column)
app: none                      # none | Web | iPhone | Server | Multiple | Unknown — PLATFORM (set by /monday-ticket; mirrors monday App column)
nature: none                   # none | Bug | Feature | Chore/Refactor | Unknown — IS-IT-BROKEN (set by /monday-ticket; mirrors monday Nature column)
```

### Board columns (monday board 18413909869)

| Column | ID | Type | Labels | Who writes |
|---|---|---|---|---|
| Status | `color_mm3gbyzr` | status | Not Started · In Progress · Verify · Near complete · Blocked · Done | /monday-resolve, /monday-review |
| Type | `color_mm5da9sj` | status | UI/UX · Data & Lifecycle · Authorization · Media · Infrastructure · Unknown | **/monday-ticket** (on deep dive) |
| App | `color_mm5dgrcn` | status | Web · iPhone · Server · Multiple · Unknown | **/monday-ticket** (on deep dive) |
| Nature | `color_mm5d8n4c` | status | Bug · Feature · Chore/Refactor · Unknown | **/monday-ticket** (on deep dive) |
| Priority | `color_mm3gtx6x` | status | Critical · High · Medium · Low | (human-set) |

Completed group: `group_mm3g94qf`. All status columns are set with `change_simple_column_value` (label text). `/monday-ticket` classifies three orthogonal axes on each deep dive — the only monday writes that skill makes:
- **Type** = the primary impacted *area* of the app, chosen by the GOAL of the work, not the files touched (a UI/UX feature that needs a server tweak is still `UI/UX`). Areas: **UI/UX**, **Data & Lifecycle** (backend/data behavior, sync, persistence), **Authorization** (access **&** identity — authentication/onboarding like phone/SMS verification & login, plus RBAC/ownership, incl. the auth integrations behind them), **Media** (images/video/storage), **Infrastructure** (build/deploy/perf/tech-debt), **Unknown**.
- **App** = which *platform's* code changes (from the Affected-areas Platform).
- **Nature** = is it a *Bug*, a *Feature*/enhancement, or a *Chore/Refactor*.

(Type ID changed 2026-07-19 when the column was rebuilt from a mixed Bug/UI/UX/… set to the area-only axis; old ID `color_mm5db2ct` is retired.)

### `affected_areas` semantics — the gate

| Value | Meaning | Who sets it |
|---|---|---|
| `none` | No area mapping yet | stub creation |
| `provisional` | Inferred from ticket text / prior analysis; screenshots NOT viewed | /monday-review, manual notes |
| `confirmed` | /monday-ticket viewed the attachments and verified every in-scope path exists on main | /monday-ticket ONLY |

`/monday-resolve` requires `confirmed`. If the user insists on resolving a `provisional` ticket, the skill must get an explicit one-off override ("resolve anyway without a deep dive?") and record the override in the resolution log.

## The Affected areas section — what "good" looks like

The whole point is **sibling disambiguation**: MakeReady has families of near-identical surfaces, and a fix aimed at one must not bleed into the others. Canonical example: ticket 12268478769 says "add a bible verse here" — there are four activity editors on iPhone (Read, Exegesis, Write, Video) plus web LeaderApp twin panes; the screenshot shows the **Edit Read Activity** page, so only `EditReadActivityPage.swift` is in scope and the siblings are *explicitly listed as out of scope*.

Required structure:

```markdown
## Affected areas

### In scope
- **Platform:** iPhone (leader authoring)          ← iphone | web-member | web-leader | server | multiple
- **Screen:** Edit Read Activity — `iphone/MakeReady/Pages/Manage/Program/EditReadActivityPage.swift`
- **Component(s):** source menu (`openSourceMenu()`, lines ~512-535)
- **Endpoints:** none (UI-only)                    ← always state, even if "none"

### Explicitly out of scope
- `EditExegesisActivityPage.swift`, Write/YouTube editors — sibling editors not referenced by the report
- Web LeaderApp twin `client/resources/js/islands/leader-app/components/edit-read-activity-pane.vue` —
  same feature on web; NOT in the screenshot. If the fix should apply there too, that is a scope
  expansion the user must approve.

### Cross-app impact
Per the root CLAUDE.md impact table: none — UI-only change on one platform.
(If a server/schema change is required, name BOTH consumers here.)
```

Rules:
1. Every in-scope file path must be verified to exist on `main` (glob it) — no paths from memory.
2. Out-of-scope must name the sibling surfaces someone could plausibly confuse with the target (other activity editors, web twins of iPhone screens, member vs. leader variants, legacy `/admin-legacy` vs. LeaderApp).
3. Cross-app impact must be explicitly assessed using the table in `.claude/CLAUDE.md` (schema → both consumers; auth → all three apps; etc.).
4. Shared components (design tokens, `MarkdownEditor.swift`, shared SCSS, common Vue components) get a callout: touching them affects screens beyond this ticket, so /monday-resolve must confirm with the user first.

## Status lifecycle

```
open → in-progress (resolve started) → resolved-pending-verify (fix landed, runtime check pending)
     → closed (verified + monday Done + moved to Completed group)
```

Monday mirror: `open` ↔ Not Started; `in-progress` ↔ In Progress; **`resolved-pending-verify` ↔ board status "Verify"** (the dedicated fixed-but-unverified state) with an evidence comment saying what landed and what check remains; `closed` ↔ Done + Completed group. Use "Verify", not "In Progress", for a landed-but-unverified fix so it's distinguishable from work still underway.

## Tagging people in comments

To reference a person in an update, write **plain text `@Name`** (e.g. `@Scott Stickane`). Do NOT try to build a real mention — Monday's `create_update` API strips mention markup (`data-mention-*` attributes), and `create_notification` fires an unconfirmable ping with no in-thread chip. The plain `@Name` reads clearly; the board owner converts it to a real tag manually in the Monday UI. So: no mention HTML, no `create_notification` — just the `@Name` text.

## Invariants

- Never mark a monday ticket Done without runtime verification (device/browser/capture) or code-level proof — a wrong Done erodes trust in the whole board.
- Every monday mutation gets an evidence comment (commit hash + one-line summary) so closures are auditable.
- Dossiers are append-mostly: Triage history and Resolution log grow; verbatim reports are never rewritten.
- After any stage, the dossier must be self-sufficient: a fresh Claude session reading only the dossier (plus code) can continue the work.
