---
description: Commit all changes and push to remote
---

Commit all uncommitted changes and push to the remote repository.

**Your task:**
1. Run `git status` to see all modified and untracked files
2. Run `git diff --stat` to summarize changes
3. Run `git log --oneline -5` to see recent commit message style
4. Stage all changed files with `git add -A`
5. Generate a concise commit message that summarizes the changes (1-2 sentences focusing on the "why")
6. Commit with the generated message, including the co-author trailer
7. Push to the remote

**Commit message format:**
```
Summary of changes

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

**Important:**
- Working directory is `/Users/lukekeith/www/makeready/iphone`
- Do NOT ask for confirmation — just commit and push
- Do NOT skip any files — stage everything
- Keep the commit message concise and descriptive
- Always include the Co-Authored-By trailer
- Report the commit hash and push result when done
