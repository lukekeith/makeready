# Monitor CI

Monitor the latest GitHub Actions CI/CD runs until they complete.

## Instructions

### 1. Get Latest Runs

```bash
cd /Users/lukekeith/www/makeready && gh run list --limit 4 --json databaseId,displayTitle,name,status,conclusion,createdAt
```

Identify the in-progress runs. If all runs are already completed, report their status and stop.

### 2. Poll Until Complete

For each in-progress run, poll every 30 seconds using:

```bash
gh run view {runId} --json status,conclusion,jobs --jq '{status, conclusion, jobs: [.jobs[] | {name, status, conclusion}]}'
```

### 3. On Failure

If any run fails, immediately fetch the failure logs:

```bash
gh run view {runId} --log-failed | tail -30
```

Report which job failed and the relevant error output.

### 4. Report

Show a summary table:

| Workflow | Status | Duration |
|----------|--------|----------|

If all passed, confirm Railway should pick up the changes.
If any failed, show the error and suggest a fix.
