# Claude Token Budget Model (Fable 5 "Extra Tokens")

As of **July 7, 2026**, Claude Fable 5 usage in Claude Code bills as **extra tokens** rather than drawing from the $200/mo Max subscription. Opus 4.8 remains covered by the subscription. This model estimates the monthly extra-token budget needed to execute the 12-month roadmap — **based on measured historical usage, not assumptions**.

## Pricing (published, per million tokens)

| Model | Input | Output | Cache read | Cache write (5m) |
|---|---|---|---|---|
| **Fable 5** | $10 | $50 | ~$1 | $12.50 |
| Opus 4.8 (plan-covered) | $5 | $25 | ~$0.50 | $6.25 |

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

Two structural facts that keep costs manageable:
1. **97.4% of input is served from prompt cache** at ~$1/M (Fable 5) — the dominant cost line, but 10× cheaper than fresh input.
2. Fresh input is nearly negligible (0.3%), so the $10/M sticker price barely matters.

**Measured model split:** 31% of processed tokens already ran on Fable 5 (1.9B on Opus 4.8, 0.9B on Fable 5, small Haiku remainder). The budget below uses this *measured* mix, not a guess.

## What the measured usage costs

- The measured **Fable 5 slice alone** would have billed **$1,210 over 25 days ≈ $338/week ≈ $1,465/month** as extra tokens.
- If **everything** had billed at Fable 5 rates: ~$1,206/week ≈ $5,220/month (the ceiling).
- Rounded planning rate: **$340 per work-week** of extra tokens at the measured mix.

## Scenarios (monthly extra-token cost, at measured usage intensity)

| Scenario | Fable 5 share | $/week | $/month | 12-month total |
|---|---|---|---|---|
| Conservative | 10% | ~$121 | ~$520 | ~$6,300 |
| **Measured mix (recommended)** | **~31% (observed)** | **~$338** | **~$1,465** | **~$17,600** |
| Aggressive | 50% | ~$603 | ~$2,610 | ~$31,300 |
| Ceiling (all-Fable) | 100% | ~$1,206 | ~$5,220 | ~$62,700 |

## Recommended budget

> **$1,500/month for extra tokens** (measured mix, rounded up), on top of the existing **$200/mo Max plan**.
>
> Total AI tooling cost: **~$1,700/mo ≈ $20,400/yr** — the leverage that sustains ~190 commits/month from a single developer.

Note: the measurement window was a peak month (13.5k assistant messages). Calmer months scale below budget; the number above is a safe ceiling for planning.

## Per-feature allocation (measured rates: 800M processed + 3.1M output per work-week, $340/wk extra)

| Feature | Work weeks | Input processed | Output | Extra cost |
|---|---|---|---|---|
| Web parity completion | 8 | 6.4B | 24M | $2,720 |
| Collaborator invitations | 5 | 4.0B | 15M | $1,700 |
| ACL permissions | 6 | 4.8B | 18M | $2,040 |
| Leader community marketplace | 12 | 9.6B | 36M | $4,080 |
| Org SSO & domain access | 5 | 4.0B | 15M | $1,700 |
| Member analytics | 7 | 5.6B | 21M | $2,380 |
| AI growth insights | 8 | 6.4B | 24M | $2,720 |
| Hardening buffer | 2 | 1.6B | 6M | $680 |
| **Total** | **53** | **~42.4B** | **~159M** | **~$18,020** |

## Ongoing AI runtime costs (separate from development)

The AI Growth Insights feature (and existing Claude-powered media tagging) creates **production** API costs independent of development tokens. At launch scale these are small (batchable, Haiku/Sonnet-tier for summarization), but they should get their own line item once member analytics establishes volume. Rough planning figure: $0.01–0.05 per member per month at Sonnet-tier batch pricing.

## Reproducing the measurement

The analysis script sums `message.usage` fields (input, output, cache read/write) from every `*.jsonl` under `~/.claude-home/projects/-Users-lukekeith-www-makeready*`, deduplicated by message id and bucketed by month and model. Re-run it after a few more months of history to tighten the weekly averages.

All levers live in `timeline.json → meta.budget`; per-feature figures are `weeks × weekly measured rates` and reprice automatically with schedule changes.
