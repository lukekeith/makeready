---
description: Resolve the unresolved compare comments for ONE comparison — read its screenshots + data + version, auto-fix the clear ones (edit → recapture → verify → reply + resolve), and ask when a comment needs a decision. (Copied by the Compare UI's "Command" button → "Resolve comments".)
argument-hint: <comparison-id>
---

# Compare & resolve — $ARGUMENTS

Resolve the unresolved comments for the comparison **$ARGUMENTS**, using the
**makeready-capture** MCP tools (they read the Postgres capture DB). The iPhone render is
the design reference unless a comment says otherwise; the **web** implementation is what you edit.

Process the comments one comparison at a time, scoped to this one:

1. Call `list_unresolved_comments` with `comparisonId: "$ARGUMENTS"`. If none, say so and stop.
2. For each comment, one at a time:
   - **Read** `latestScreenshots.iphone`, `latestScreenshots.client`, and `pinnedScreenshot`
     (Read tool on the absolute paths); use the pin `position` to find the exact element.
     (A blank cover on the iPhone side = remote-image snapshot limitation; don't chase it.)
   - **Use `commentedElement` when present** — it's the exact DOM element the pin resolved to:
     its BEM `selector` (e.g. `.CardEvent__block`) maps straight to the SCSS rule to edit, and
     `computedStyles` gives the current values. A terse comment like "bottom radius should be 0"
     plus `selector: .CardEvent__block` / `borderRadius: 8px` is enough to make the fix with no
     guessing about which object is meant.
   - **Decide:** if it needs a human call (ambiguous, a tradeoff, multiple readings, or it
     would change shared tokens / the iPhone app) → `reply_comment` with the options and
     **ask the user**; leave it unresolved. Otherwise auto-fix.
   - **Fix** the web component (`component`/`clientView` → `client/resources/js/components/...`
     `.vue`/`.scss`, or the Blade view for pages) with the smallest token-faithful change.
   - **Recapture + verify:** `cd capture && node runners/compare/capture.mjs $ARGUMENTS <viewport> client`
     (needs Laravel :8001 + client Vite). A new version is created; old screenshots are kept.
     `get_latest_screenshots` then Read the new web shot to confirm it's fixed.
   - **Resolve:** if fixed → `reply_comment` (what changed) then `resolve_comment`; else reply
     with status and leave unresolved.
3. Summarize what you resolved, what needs the user's decision, and anything that failed
   verification. Tell the user to refresh `http://localhost:5950/compare/$ARGUMENTS`.
