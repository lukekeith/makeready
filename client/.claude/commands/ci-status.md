Check GitHub Actions CI status.

## Instructions

Run `gh run list --limit 5` to show recent CI runs.

If any run is `in_progress`, wait 30 seconds and check again (up to 5 times) until it completes.

If any run failed, run `gh run view <id> --log-failed` to show the error details.

Report the results in a table: status, commit message, duration, and time.
