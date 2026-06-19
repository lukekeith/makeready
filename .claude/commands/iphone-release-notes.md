---
description: Generate prose iPhone release notes (improvements + where to test) into docs/qa/
---

Generate polished, **prose** iPhone release notes for the QA team covering every
improvement made since the **last TestFlight archive**, and tell testers where to
focus. Save to `docs/qa/iphone-<TODAY>.md`.

Run from the monorepo root (`/Users/lukekeith/www/makeready`).

The output should read like `docs/progress/2026-06-12.md` — a model of the target
format. Read that file first to match its voice, density, and structure.

## Steps

1. **Find the last MakeReady archive + its date/version:**
   ```bash
   ARCH=~/Library/Developer/Xcode/Archives
   LASTARCH=$(find "$ARCH" -maxdepth 2 -name "*.xcarchive" 2>/dev/null | while read -r a; do
     n=$(/usr/libexec/PlistBuddy -c "Print :Name" "$a/Info.plist" 2>/dev/null)
     [ "$n" = "MakeReady" ] && echo "$(stat -f %m "$a")|$a"
   done | sort -n | tail -1)
   A="${LASTARCH#*|}"; SINCE=$(date -r "${LASTARCH%%|*}" +"%Y-%m-%d %H:%M:%S")
   SINCE_DATE=$(date -r "${LASTARCH%%|*}" +"%Y-%m-%d")
   /usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$A/Info.plist"
   echo "since: $SINCE"
   ```
   If no archive is found, fall back to the most recent `docs/qa/iphone-*.md` or
   `docs/progress/*.md` date as the window start, and say so in the header.

2. **Gather changes since `$SINCE`:**
   - `git log --since="$SINCE" --pretty=format:"%h | %ad | %s" --date=format:"%Y-%m-%d"` — all commits (count them)
   - `git log --since="$SINCE" --name-only --pretty=format: -- iphone/MakeReady/` — iPhone app files touched (derive the affected areas from Pages/Components/State/Services, not just commit subjects)
   - `git status --short` and `git diff` — current uncommitted/untracked work (**include it**)
   - For anything ambiguous, read the actual diff/files to describe the *user-visible* effect, not the implementation.

3. **Write the release notes** to `docs/qa/iphone-<TODAY>.md` (today's date via `date +%Y-%m-%d`). Match the reference file:
   - **Title:** `# Release Notes — <TODAY>`
   - **Window blockquote:** `> Window: since the <SINCE_DATE> archive — <N> commits. (Sized for TestFlight's 4,000-char field.)`
   - **Body: prose paragraphs, no bullet lists, no commit hashes.** Lead with the biggest user-facing change and work down. Group by app area (e.g. Bible search, media library, navigation, error handling, stability/security). Each paragraph describes what a tester can now *see or do*, in plain language.
   - **Exclude / clearly demote infra:** CI, build config, monorepo plumbing, and **web-only (client/Laravel/Vue) work that does not change the iPhone app** — either omit or fold into a single short closing line marked as not iPhone-facing.
   - **Backend/API changes** the app consumes (SMS, completion, endpoints, push) belong in the notes — describe them by their in-app effect.
   - **Final paragraph — required:** a single `Please focus testing on:` sentence naming the specific screens and flows most affected, with concrete things to try (e.g. "try a save in airplane mode and confirm Retry works"). This is the most important part — make the QA targets specific and actionable.
   - Keep the whole body comfortably under ~4,000 characters so it can paste into TestFlight's "What to Test."

4. **Report** the file path and a 2–3 line TL;DR.

## Notes
- `docs/qa/` may not exist yet — create it (`mkdir -p docs/qa`).
- This is the prose, QA-focused sibling of `/progress-archive` (structured) and `/progress-archive-summary` (short TestFlight blurb). Reuse the same "since last archive" window.
- Do NOT build, archive, or run any `xcodebuild`/simulator commands.
