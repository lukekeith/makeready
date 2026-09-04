---
description: Resolve every unresolved iPhone component-browser comment in a filesystem SCOPE — Card/CardEvent (one component), Card/** (a folder), ** (everything), or a unique component name. Edits the SWIFT component (or its fixture) per comment, replies + resolves, then batch-recaptures the touched components so fresh renders land. (Copied by the /components UI's tree-row copy action.)
argument-hint: <scope — e.g. Card/CardEvent, Card/**, or a bare unique component name>
---

# Component resolve — $ARGUMENTS

Resolve every unresolved comment in the scope **$ARGUMENTS** of the iPhone component browser
(`http://localhost:5950/components`). Unlike `/compare-resolve` (where the iPhone render is the
reference and the WEB twin gets edited), here **the iPhone component itself is the thing being
changed** — a comment about the render is a change request against the Swift source; a comment
about the data is a change request against the fixture JSON. Never edit web code from this
command.

## Procedure

1. **Resolve the scope.** Call the `makeready-capture` MCP tool `resolve_scope` with
   `scope: "$ARGUMENTS"` (fallback if the tool is missing — MCP not reconnected since it
   shipped: `curl -s "localhost:5951/api/components/scope?scope=<url-encoded scope>"`, the
   identical payload). Scope grammar: `A/B/Name` one component · `A/B/**` or bare `A/B` a
   folder recursively · `**` everything · a bare unique component name. A scope error
   (unknown / ambiguous / basename collision) → report it verbatim and stop. Zero components →
   say so, stop. Zero unresolved comments → report the scope size ("N components, nothing
   unresolved") and stop.

2. **Work per component, oldest comment first.** The payload's comments are iPhone-platform
   only, across ALL variants and versions. For each comment:
   - **Read the renders**: `pinnedScreenshot` (the exact render the pin was made on) and
     `latestScreenshots.iphone`. Heed `versionLabel`: a comment labeled `old — captured
     <date>; current version is <id>` was made on an OLD render — treat it as a REFERENCE
     against the current render (e.g. "I liked this older spacing — bring it back"): compare
     the two images before deciding what to change. `current` = about the live render.
     `unanchored` = no render existed; judge from the text + latest render.
   - Use the pin `position` (fraction and px) to find the element in the image.
   - **Decide**: ambiguous, a tradeoff, multiple readings, or it would change shared design
     tokens or app-wide behavior → `reply_comment` with the options and leave it
     UNRESOLVED; continue to the next comment. Otherwise fix it.
   - **Fix**: edit the component's `swiftFile` (from the payload) — smallest faithful change;
     follow `/transition-review` rules if the diff touches animation/transition code. A
     comment about fixture DATA (wrong sample text, wants a different variant value) edits
     `fixtureFile` instead.
   - **Reply + resolve**: `reply_comment` describing exactly what changed (file + what), then
     `resolve_comment`.

3. **Build-check before recapturing** (a broken build burns an xcodebuild cycle):
   `npm run ios:build-check` from the repo root. Red → fix your edits until green.

4. **Batch recapture the touched components** — one run per distinct viewport among the
   comments you resolved (default `pro-max`), viewport FIRST:
   `cd capture && node runners/compare/capture-batch.mjs <viewport> <comparisonId> …`
   (comparisonIds from the payload — they can differ from component names, e.g.
   `card-study`). Fresh versions land; history is kept automatically.

5. **Verify**: `get_latest_screenshots` per touched comparison; Read the new PNG(s) and
   confirm each resolved comment's change is visible. A change that didn't take → reopen
   (`resolve_comment` with `resolved: false`) with a reply saying what happened.

6. **Summarize** per component: resolved / replied-awaiting-decision / failed-verification,
   with the files you touched. Point the user at
   `http://localhost:5950/components/<path>` for each.

## Rules

- The invocation is the scope and nothing else — all context comes from the MCP/API at run
  time.
- Swift edits follow the iPhone app's house rules (`iphone/.claude/CLAUDE.md`); components
  live under `iphone/MakeReady/Components/`.
- Never touch `client/`, never run web captures, never resolve a comment you didn't act on.
- Commits stay the user's call — leave the working tree for review unless they've said
  otherwise.
