---
name: monday-resolve
description: Resolve a monday.com ticket with a user-described solution — /monday-resolve <ticket id|url|title> <resolution description>. Implements the fix STRICTLY scoped to the affected areas documented in the ticket's dossier (docs/monday/tickets/<id>.md), verifies it, commits, updates the monday ticket with an evidence comment/status, and appends to the local dossier + triage notes. Hard-gated: refuses to run unless the dossier has confirmed affected areas (from /monday-ticket), so fixes never bleed into sibling screens. Use when the user describes how a ticket should be fixed and wants it done end-to-end.
---

# Monday Ticket Resolve

You are implementing the user's described solution to ONE monday.com ticket, end-to-end: scoped implementation → verification → commit → monday update → local record. The pipeline contract lives in `docs/monday/PIPELINE.md` — read it first. The defining property of this skill is **scope discipline**: the fix touches only the surfaces the dossier's affected-areas contract names, so a fix aimed at (say) the Edit Read Activity page never bleeds into the Exegesis editor, the web twin pane, or a shared component.

## 0 — Parse the invocation

`/monday-resolve <ticket ref> <resolution description>`

- **Ticket ref** (first token): numeric id, monday URL (`…/pulses/<id>`), or fuzzy title (resolve against `docs/monday/tickets/*.md` frontmatter first, then the board; ambiguous → ask).
- **Resolution description** (the rest): the user's design for the fix. This text is the spec — implement *it*, not your own preferred fix. If it's missing or too thin to act on ("fix it"), ask for the intended solution before doing anything.

## 1 — Load the dossier and enforce the gates

Read `docs/monday/tickets/<id>.md`. Refuse to proceed (with a clear explanation and the exact next command to run) when:

1. **No dossier exists** → "Run `/monday-ticket <id>` first to build the dossier."
2. **`affected_areas` is not `confirmed`** → the deep dive hasn't verified the screen against the ticket's screenshots. Offer two paths: run `/monday-ticket <id>` now (preferred), or an explicit user override for this one run ("resolve anyway on provisional scope?"). An override must be recorded in the Resolution log. Never self-override.
3. **`status` is `closed`** → report that and stop.

Also load the ticket live from monday (auth per `/monday-review`; never print the token) to catch new comments since the dossier was written — a new report may have changed the problem or the scope. If it has, stop and say the dossier is stale; re-run `/monday-ticket`.

## 2 — Reconcile the user's resolution against the scope contract

Before writing any code, produce a short **scope check**:

1. List every file you expect to create/modify for the user's resolution.
2. Map each to the dossier's **In scope** entries.
3. Flag anything that falls outside:
   - a file in the **Explicitly out of scope** list (e.g. the resolution says "and do the same on web" but the web twin is out of scope),
   - a **shared component** (`MarkdownEditor.swift`, shared SCSS/tokens, common Vue components) — touching it affects screens beyond this ticket,
   - a **cross-app impact** the dossier says doesn't exist (e.g. the fix needs a server/schema change but the dossier says UI-only).

If anything is flagged: STOP and present the conflict to the user — either they approve the scope expansion (record it in the Resolution log, and consider whether `/monday-ticket` should re-run to re-scope), or the resolution is narrowed to fit. **Never silently expand scope.** Multi-sub-issue tickets: the user's resolution usually targets one sub-issue; state which one and leave the others' status untouched.

## 3 — Implement

- Follow the resolution as described, constrained to the approved file list. New files are fine when they live within an in-scope screen/feature.
- Match repo conventions (each app has its own `.claude/CLAUDE.md`; iPhone work should use the relevant iphone skills — `present-overlay`, `push-page`, `animation-debug`, `transition-review` — when the change touches those domains).
- If mid-implementation you discover the fix genuinely requires an out-of-scope file, go back to step 2's stop-and-ask. Do not finish "while you're in there" improvements.

## 4 — Verify

Run the dossier's **Verification** section, strongest available form:
- Build/typecheck the touched app (iPhone: `rebuild-iphone` skill / xcodebuild; client: its build; server: tests).
- Execute the manual repro or capture-fixture check where feasible (`/verify` behavior: drive the affected flow, not just the compiler). For iPhone-simulator or on-device checks you can't perform, say exactly what remains for the user to check.
- **Scope audit:** `git diff --name-only` — every changed file must be on the approved list from step 2. Any stray file: revert it or stop and explain.

## 5 — Commit

One commit for the fix, message referencing the ticket: `<summary> (monday#<id>)`, ending with the repo's standard co-author line. Do not push unless the user asked or an established deploy skill flow is explicitly requested.

## 6 — Update monday (authorized by the user invoking this command)

Board `18413909869`, status column `color_mm3gbyzr`, completed group `group_mm3g94qf` (other boards: discover per `/monday-review`).

- **Always** post an evidence comment: what was changed, commit hash, how it was verified, and — for multi-issue tickets — which sub-issue this resolves and which remain.
- **If verification passed at runtime** (flow actually driven, or code-level proof is airtight): set status Done and move to the completed group.
- **If verification is pending** (needs device/TestFlight/deploy): set status In Progress; the comment states exactly what check remains. Do NOT mark Done — a wrong Done erodes trust in the board (see PIPELINE.md invariants).
- Multi-issue tickets with sub-issues remaining open: comment only; leave status.

## 7 — Update the local store

1. **Dossier** `docs/monday/tickets/<id>.md`:
   - Append to **Resolution log**: date, the user's resolution verbatim (or tight paraphrase), files changed, commit hash, verification result, monday actions taken, any approved scope expansions or overrides.
   - Frontmatter `status`: `closed` (verified + Done) or `resolved-pending-verify`.
2. **Latest triage file** (`docs/monday/triage-*.md`, newest): move/annotate the ticket's line to reflect the new state.
3. **README.md** ticket → work-item map: mark the work item(s) resolved if fully covered.

## 8 — Report

Lead with the outcome: what was fixed, in which files, commit hash, verification result, and exactly what monday + local updates were made. If anything is pending (device check, remaining sub-issues), list it as the explicit next step.
