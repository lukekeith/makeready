# Claude Token Budget (100% Fable 5)

As of **July 7, 2026**, Claude Fable 5 usage in Claude Code bills as **extra tokens** outside the Max subscription. **This budget assumes all development runs on Fable 5 — no Opus usage at all**, so no development tokens are offset by the $200/mo plan. Figures are based on measured historical usage, not assumptions.

## Pricing (published, per million tokens)

| Model | Input | Output | Cache read | Cache write (5m) |
|---|---|---|---|---|
| **Fable 5** (all development) | $10 | $50 | ~$1 | $12.50 |

## Measured usage (actual, not modeled)

Parsed from local Claude Code session transcripts for the MakeReady projects — 233 files, 13,501 assistant messages, deduplicated by message id.

**Window: Jun 11 → Jul 5, 2026 (25 days).** Older transcripts are not retained locally; this window covers the iOS architecture audit, semantic Bible search, and the parity program — a representative peak-intensity period.

| Metric | 25-day total | Per week |
|---|---|---|
| Input tokens processed | **2,914.6M (2.9B)** | ~816M |
| — cache reads (97.4%) | 2,839.6M | ~795M |
| — cache writes | 65.2M | ~18.3M |
| — fresh input (0.3%) | 9.8M | ~2.75M |
| Output tokens | **11.0M** | ~3.1M |

Two structural facts that keep costs manageable even at 100% Fable 5:
1. **97.4% of input is served from prompt cache** at ~$1/M — the dominant cost line, but 10× cheaper than fresh input.
2. Fresh input is nearly negligible (0.3%), so the $10/M sticker price barely matters.

## What the measured usage costs at Fable 5 rates

Billing the entire measured window at Fable 5 rates:

| Line | Tokens | Rate | Cost (25 days) |
|---|---|---|---|
| Fresh input | 9.8M | $10/M | $98 |
| Cache reads | 2,839.6M | $1/M | $2,840 |
| Cache writes | 65.2M | $12.50/M | $815 |
| Output | 11.0M | $50/M | $551 |
| **Total** | | | **$4,304** |

That is **~$1,206 per week ≈ $5,220 per month** at measured intensity. Planning rate used below: **$1,200 per work-week**.

## Recommended budget

> **$5,500/month for Fable 5 tokens** (measured burn + ~5% headroom).
>
> ~**$66,000/yr** of AI development tokens — the leverage that sustains ~190 commits/month from a single developer. The $200/mo Max plan, if retained, is tooling access only and offsets none of this.

Note: the measurement window was a peak month (13.5k assistant messages). Calmer months land below budget; $5,500 is a planning ceiling.

**Cost-reduction lever (not assumed):** routing routine implementation to plan-covered Opus 4.8 historically covered ~69% of tokens, which would cut the extra-token bill to roughly $1,500/mo. This budget deliberately does not count on it.

## Per-feature allocation (measured rates: 800M processed + 3.1M output per work-week, $1,200/wk)

Features decompose into per-app epics in `timeline.json` (API / Web / iPhone / Tooling); weeks below are the feature totals across all parts.

| Feature | Work weeks | Input processed | Output | Fable 5 cost |
|---|---|---|---|---|
| Web parity completion | 8 | 6.4B | 24M | $9,600 |
| Collaborator invitations | 5 | 4.0B | 15M | $6,000 |
| ACL permissions | 6 | 4.8B | 18M | $7,200 |
| Leader community marketplace | 12 | 9.6B | 36M | $14,400 |
| Org SSO & domain access | 5 | 4.0B | 15M | $6,000 |
| Member analytics | 7 | 5.6B | 21M | $8,400 |
| AI growth insights | 8 | 6.4B | 24M | $9,600 |
| Hardening buffer | 2 | 1.6B | 6M | $2,400 |
| **Total (committed 12 months)** | **53** | **~42.4B** | **~159M** | **$63,600** |

## Ongoing AI runtime costs (separate from development)

The AI Growth Insights feature (and existing Claude-powered media tagging) creates **production** API costs independent of development tokens. At launch scale these are small (batchable, Haiku/Sonnet-tier for summarization), but they should get their own line item once member analytics establishes volume. Rough planning figure: $0.01–0.05 per member per month at Sonnet-tier batch pricing.

## Reproducing the measurement

The analysis script sums `message.usage` fields (input, output, cache read/write) from every `*.jsonl` under `~/.claude-home/projects/-Users-lukekeith-www-makeready*`, deduplicated by message id and bucketed by month and model. Re-run it after a few more months of history to tighten the weekly averages.

All levers live in `timeline.json → meta.budget`; per-epic figures are `weeks × $1,200` and reprice automatically with schedule changes.
