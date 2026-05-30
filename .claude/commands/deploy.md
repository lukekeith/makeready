# Deploy

Commit all changes and push to main.

## Instructions

Execute these steps in order:

### 1. Stage Everything

```bash
cd /Users/lukekeith/www/makeready && git add -A
```

### 2. Check What Will Be Committed

Run `git status` and `git diff --cached --stat` to see all staged changes.

### 3. Create Commit

Write a concise commit message summarizing the changes. Follow the repo's commit style (imperative mood, 1-2 sentences focusing on the "why"). End with:

```
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

Use a HEREDOC for the message:

```bash
git commit -m "$(cat <<'EOF'
Your commit message here

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### 4. Push to Main

```bash
git push origin main
```

### 5. Report

Show the user:
- The commit hash
- The commit message
- Number of files changed
- Confirmation that push succeeded
