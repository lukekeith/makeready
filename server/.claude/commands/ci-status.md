# CI Status Check

Check the status of GitHub Actions workflows for this repository.

## Instructions

Run the following commands to show CI/CD pipeline status:

1. **Show recent workflow runs:**
```bash
gh run list --limit 10
```

2. **Show status of the latest run on current branch:**
```bash
gh run list --branch $(git branch --show-current) --limit 1
```

3. **If there's a failing run, show details:**
```bash
gh run view $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --log-failed
```

## Output Format

Present the results in a table showing:
- Workflow name
- Status (success/failure/in_progress)
- Branch
- Commit message
- Duration
- When it ran

If the latest run failed, show which job failed and the relevant error logs.
