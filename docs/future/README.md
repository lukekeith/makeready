# MakeReady Development Timeline (Investor View)

This directory is the single source of truth for the investor-facing development timeline served at **`/investor`** on the web client.

## Files

| File | Purpose |
|---|---|
| `timeline.json` | Canonical dataset: every completed epic (mined from git history), the in-progress work, and the 12-month roadmap with estimates and token budgets. The `/investor` page renders this data. |
| `velocity.md` | How development velocity was measured from ~1,550 commits across five repositories (Oct 2025 → Jul 2026). |
| `roadmap.md` | Narrative 12-month plan: the seven committed features, sequencing rationale, and recommended additions cross-referenced against `docs/plans/user-stories.txt`. |
| `token-budget.md` | The Claude Fable 5 token cost model: assumptions, formulas, scenarios, and the recommended monthly budget beyond the $200/mo Max plan. |

## Keeping the /investor page in sync

The Vue island bundles a copy of the dataset at
`client/resources/js/islands/investor-timeline/timeline-data.json`.

After editing `timeline.json`, refresh the copy and rebuild:

```bash
cp docs/future/timeline.json client/resources/js/islands/investor-timeline/timeline-data.json
cd client && npm run build
```

## Status vocabulary

- `done` — shipped, dated from actual commit history (with commit counts)
- `in-progress` — currently being built
- `planned` — committed 12-month roadmap (Jul 2026 → Jun 2027)
- `proposed` — recommended additions beyond the 12-month window, drawn from the original user stories
