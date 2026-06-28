---
description: Open all unresolved compare comments from the capture database and process each — read both screenshots + data + version, auto-fix the clear ones (edit → recapture → verify → reply + resolve), and start a conversation when a comment needs your decision.
argument-hint: "[comparison-id]  (optional — limit to one comparison)"
---

# Compare: process unresolved comments

Drive this with the **makeready-capture** MCP tools (they read the Postgres capture DB).
The iPhone render is the design reference unless a comment says otherwise; the **web**
implementation is what you edit.

## 1. Gather

Call `list_unresolved_comments`${ARGUMENTS:+ with `comparisonId: "$ARGUMENTS"`}. Each comment includes:
its comparison + type, the `component`/`clientView`/`iphoneView`, `device`, `viewport`,
both platforms' latest screenshot **file paths**, the `pinnedScreenshot` it was drawn on,
the `version` (gitSha, capturedAt, sourceHash), the `sharedData` snapshot, the pin
`position` (xFraction/yFraction + xPx/yPx), and the message `thread`.

If there are none, say so and stop. Otherwise list what you're about to process.

## 2. Process each comment, one at a time

a. **Look.** Read `latestScreenshots.iphone`, `latestScreenshots.client`, and the
   `pinnedScreenshot` (Read tool on the absolute paths). Use the pin `position` to find the
   exact element the user means. (A blank cover/photo on the iPhone side is a snapshot
   limitation for remote images — never "fix" the web to match a missing image.)
   When `commentedElement` is present it pins down the exact DOM element: its BEM `selector`
   (e.g. `.CardEvent__block`) → the SCSS rule to edit, with `computedStyles` giving current
   values — so a terse comment needs no guesswork about which object it refers to.

b. **Understand** the ask from the `thread` + position (+ `commentedElement`).

c. **Decide — does it need the user?**
   - **Yes** (ambiguous intent, a real visual tradeoff, more than one valid reading, or it
     would change shared design tokens / the iPhone app): do NOT edit. `reply_comment` with
     the options/why, then **ask the user in this conversation** and move on. Leave it
     unresolved.
   - **No — a clear, mechanical fix:** continue to (d).

d. **Fix the web component.** Map `component`/`clientView` to its source under
   `client/resources/js/components/.../<name>/` (`.vue` + `.scss`); for page comparisons use
   the Blade view named in `clientView`. Make the smallest change that resolves the comment,
   using existing design-system tokens.

e. **Recapture + verify** (history is preserved — a new version is created, old screenshots
   are kept):
   ```
   cd capture && node runners/compare/capture.mjs <comparisonId> <viewport> client
   ```
   (Needs Laravel on :8001 + the client Vite dev server. If it can't connect, tell the user
   how to start them and skip verification for now.) Then call `get_latest_screenshots` and
   **Read the new web screenshot** to confirm the issue is actually fixed.

f. **Resolve.** If fixed: `reply_comment` with a concise note of what you changed, then
   `resolve_comment`. If still wrong after a couple of attempts: `reply_comment` with the
   status and leave it unresolved.

## 3. Report

Summarize: auto-fixed + resolved (with the comment ids), needs-your-decision (list each with
its question), and any that failed verification. Tell the user to refresh
`http://localhost:5950/compare/<id>` to review.
