---
description: Summarize all changes since the last Xcode archive into docs/progress for iPhone release notes
---

Generate iPhone release notes for the QA team covering everything changed since
the **last TestFlight archive**, and save them to `docs/progress/`.

Run from the monorepo root (`/Users/lukekeith/www/makeready`).

## Steps

1. **Find the last MakeReady archive + its date/version:**
   ```bash
   ARCH=~/Library/Developer/Xcode/Archives
   LASTARCH=$(find "$ARCH" -maxdepth 2 -name "*.xcarchive" 2>/dev/null | while read -r a; do
     n=$(/usr/libexec/PlistBuddy -c "Print :Name" "$a/Info.plist" 2>/dev/null)
     [ "$n" = "MakeReady" ] && echo "$(stat -f %m "$a")|$a"
   done | sort -n | tail -1)
   A="${LASTARCH#*|}"; SINCE=$(date -r "${LASTARCH%%|*}" +"%Y-%m-%d %H:%M:%S")
   /usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$A/Info.plist"
   /usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$A/Info.plist"
   echo "since: $SINCE"
   ```

2. **Gather changes since `$SINCE`:**
   - `git log --since="$SINCE" --pretty=format:"%h | %ad | %s" --date=format:"%Y-%m-%d"` — all commits
   - `git log --since="$SINCE" --name-only --pretty=format: -- iphone/MakeReady/` — iPhone app files touched (Pages/Components/State/Services)
   - `git status --short` and `git diff` — current uncommitted/untracked work (include it)
   - Next build number: `git rev-list HEAD --count`

3. **Summarize, grouped for QA** (focus on what an iPhone tester can see/verify):
   - **📱 iPhone app — user-facing** — group by area; each item gets a short **QA:** test hint. Derive areas from the changed `iphone/MakeReady/Pages|Components|State` files, not just commit subjects.
   - **🔌 Backend / API — affects in-app behavior** — server changes the app consumes (SMS, completion, preview, endpoints).
   - **🛠️ Infrastructure / dev only (no QA impact)** — CI, monorepo, build config, and **web-only (client/Laravel/Vue) work — explicitly note it is NOT in the iPhone app.**
   - **🔖 Version** — current marketing version + next build number.

4. **Write** to `docs/progress/<TODAY>.md` (today's date, `date +%Y-%m-%d`). Include: last-archive version/build + date, next build number, the date window, and commit count. If the last archive predates the monorepo consolidation (`fc69ddb`), note that pre-consolidation changes are folded into that migration commit.

5. **Report** the file path and a 2–3 line TL;DR the user can paste into Xcode's "What to Test."

## Notes
- The build number is auto-set at build time from `git rev-list HEAD --count` (a Run Script phase), so the next archive's build = that count. It reset when the app moved into the monorepo, so it may read lower than the last TestFlight build — that's fine on a new marketing version.
- Do NOT build, archive, or run any `xcodebuild`/simulator commands.
