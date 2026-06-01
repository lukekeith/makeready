---
description: One-to-two paragraph, TestFlight-ready summary of changes since the last Xcode archive
---

Produce a short, **human-readable summary (no more than one or two paragraphs)**
of what changed since the **last TestFlight archive**, written to paste directly
into TestFlight's "What to Test" field for the release. It must describe the
updates in plain language and tell testers **where to focus their QA**.

Run from the monorepo root (`/Users/lukekeith/www/makeready`).

## Steps

1. **Find the last MakeReady archive + its date:**
   ```bash
   ARCH=~/Library/Developer/Xcode/Archives
   LASTARCH=$(find "$ARCH" -maxdepth 2 -name "*.xcarchive" 2>/dev/null | while read -r a; do
     n=$(/usr/libexec/PlistBuddy -c "Print :Name" "$a/Info.plist" 2>/dev/null)
     [ "$n" = "MakeReady" ] && echo "$(stat -f %m "$a")|$a"
   done | sort -n | tail -1)
   SINCE=$(date -r "${LASTARCH%%|*}" +"%Y-%m-%d %H:%M:%S")
   ```

2. **Gather changes since `$SINCE`:**
   - `git log --since="$SINCE" --pretty=format:"%h %s"` — all commits
   - `git log --since="$SINCE" --name-only --pretty=format: -- iphone/MakeReady/` — iPhone app files touched
   - `git status --short` — current uncommitted/untracked work (include it)

3. **Write the summary.** Hard rules:
   - **One or two short paragraphs. No headings, no bullet lists, no commit hashes, no version numbers** — just prose a tester reads.
   - First sentence(s): plain-English description of the meaningful, **user-facing iPhone app** updates (skip pure infra/CI/build/test/monorepo plumbing).
   - **Explicitly exclude web-only (client/Laravel/Vue) work** — if it didn't change the iPhone app, don't mention it.
   - End with a clear **"Please focus testing on …"** sentence naming the specific screens/flows most affected.
   - Keep it tight and skimmable — aim for ~3–6 sentences total.

4. **Save** to `docs/progress/<TODAY>-testflight.md` (today's date via `date +%Y-%m-%d`), then **print the paragraph(s) verbatim** in the reply so the user can copy them straight into TestFlight.

## Notes
- This is the prose sibling of `/progress-archive` (which produces the full structured QA doc). Reuse the same "since last archive" window.
- Do NOT build, archive, or run any `xcodebuild`/simulator commands.
