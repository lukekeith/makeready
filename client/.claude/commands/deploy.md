Deploy the app to production via GitHub → Railway CI/CD pipeline.

## Steps

1. **Stage and commit ALL changes (tracked and untracked):**
   - Run `git status` to see what's changed (both modified and untracked files)
   - If there are no changes, skip to step 3
   - Stage EVERYTHING with `git add -A` — then unstage only files that must be excluded: `.histoire/`, `.mcp.json`, `.env` files, and `.bg-shell/` (`git reset HEAD <path>` for each)
   - Write a concise commit message summarizing the changes
   - Commit with the standard co-author trailer

2. **Push to GitHub:**
   - Run `git push origin main`
   - If push fails, diagnose and fix (do NOT force push)

3. **Monitor CI:**
   - Wait 30 seconds, then check `gh run list --limit 1`
   - If status is `in_progress`, wait 60 more seconds and check again
   - Repeat until the run completes (max 10 checks)
   - If CI fails, run `gh run view <id> --log-failed` to get the error
   - Fix the issue, commit, push, and restart monitoring

4. **Monitor Railway deploy:**
   - Once CI passes, switch to the Web service: `railway service link "Web"`
   - Check deploy logs: `railway logs -n 50`
   - Verify the site is live: `curl -s -o /dev/null -w "%{http_code}" https://app.makeready.org/up`
   - If the health check returns 200, report success
   - If it fails, check `railway logs -n 100` for errors and report the issue

5. **Report:**
   - Summarize: commit SHA, CI status, deploy status, health check result

## Important
- NEVER force push
- NEVER commit `.env` files (they contain secrets)
- If CI fails more than 3 times on the same issue, stop and ask the user
- The Railway CLI is linked to the MakeReady project — use `railway service link "Web"` to target the web service, `railway service link "API"` for the API
