---
description: TestFlight-ready "What to Test" summary since the last Xcode archive, with per-feature testing notes
---

Produce a **human-readable, TestFlight-ready summary** of what changed since the
**last TestFlight archive**, written to paste directly into TestFlight's "What to
Test" field. It opens with a short plain-language overview, then gives each
meaningful iPhone-app change its **own testing note** so a tester knows exactly
what to do and what "correct" looks like. Length is whatever the changes warrant —
**do not cap it at two paragraphs** — but keep every line useful (no filler).

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

3. **Write the summary.** Structure and rules:
   - **Open with a 2–4 sentence overview paragraph** in plain English — what this build is mostly about, so a tester gets the gist before the details.
   - **Then one short labeled block per meaningful iPhone-app feature/change.** Each block =
     a bolded feature name, one or two sentences on what changed, and a **"How to test:"**
     line (or 2–3 numbered steps) giving the concrete path (which screen → what to tap →
     what to enter) **and what a correct result looks like** (what the tester should see).
     Cover edge cases worth checking (empty states, permissions/disabled states, error
     handling) where they changed.
   - Group trivial polish (copy tweaks, icon/style fixes) into a single short "Also" block
     rather than a block each.
   - **No commit hashes, no version numbers, no internal ticket IDs** — tester-facing prose only.
   - First content is always the **user-facing iPhone app** changes; skip pure
     infra/CI/build/test/monorepo plumbing.
   - **Explicitly exclude web-only (client/Laravel/Vue) work** — if it didn't change the
     iPhone app, don't mention it at all.
   - **End with a "Please focus testing on …"** line naming the 2–4 highest-risk
     screens/flows in this build.
   - Length scales with the changes — a big release gets more blocks. Keep each block tight;
     every line should tell the tester something actionable.
   - **HARD LIMIT: the summary MUST be under 4000 characters** (TestFlight's "What to Test"
     field is capped at 4000). This is a strict cap, not a target. When the changes won't
     fit, do NOT overflow — condense: shorten each block's prose, merge closely related
     changes into one block, fold minor items into the "Also" line, and trim "How to test"
     to the single most important path + expected result. Preserve the highest-risk features'
     testing notes; sacrifice detail on the low-risk ones first.

4a. **Verify the length before finishing:** `wc -m < docs/progress/<TODAY>-testflight.md`.
    If it reports **4000 or more**, the file is too long for TestFlight — revise it down and
    re-check until `wc -m` is under 4000. Aim for ≤ ~3900 to leave a margin. Do not report
    success until the count is under 4000.

4. **Save** to `docs/progress/<TODAY>-testflight.md` (today's date via `date +%Y-%m-%d`), then **print the paragraph(s) verbatim** in the reply so the user can copy them straight into TestFlight.

## Notes
- This is the prose sibling of `/progress-archive` (which produces the full structured QA doc). Reuse the same "since last archive" window.
- Do NOT build, archive, or run any `xcodebuild`/simulator commands.
