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

> **$7,800/month for Fable 5 tokens.**
>
> The first 12 months carry ~77 work-weeks of the roadmap (overlapping workstreams plus the Live Events background stream), so budget = 77 × $1,200 ÷ 12 = $7,700/mo, rounded to $7,800. ~**$93,600/yr** of AI development tokens — the leverage that sustains ~190 commits/month from a single developer. The $200/mo Max plan, if retained, is tooling access only and offsets none of this.

Note: the measured single-stream burn was $5,220/mo during a peak month; the uplift covers the overlap weeks and the continuous Live Events stream.

**Cost-reduction lever (not assumed):** routing routine implementation to plan-covered Opus 4.8 historically covered ~69% of tokens, which would cut the extra-token bill to roughly $1,500/mo. This budget deliberately does not count on it.

## Hybrid scenario (Fable + Opus via the $200/mo Max plan)

The `/investor` page has a toggle between this Fable-only budget and a **hybrid** scenario matching measured history: routine implementation on Max-plan-covered Opus 4.8 (~69% of tokens), Fable 5 reserved for the hardest work (measured Fable share: 31%). Extra-token spend scales by the Fable share; the Max subscription is counted in.

| Line | Fable 5 only | Hybrid |
|---|---|---|
| Extra tokens per work-week | $1,200 | $372 (31%) |
| First 12 months, 77 wks | $92,400 | $28,644 + $2,400 subscription (12 mo) = **$31,044** |
| Recommended monthly budget | $7,800/mo | **$2,600/mo** (incl. the $200 plan) |
| Full roadmap, 126 wks | $151,200 | $46,872 + $4,000 subscription (20 mo) = **$50,872** |

Numbers live in `timeline.json → meta.budget.hybrid`. The hybrid scenario assumes Opus 4.8 stays available under the Max plan at current limits and that the 69/31 routing split holds for future work.

## Per-epic allocation (measured rates: 800M processed + 3.1M output per work-week, $1,200/wk)

The roadmap is seven consolidated epics (each with internal phases — see `roadmap.md`); per-app parts live in `timeline.json` (API / Web / iPhone / Tooling). Weeks below are epic totals across all parts.

| Epic | Work weeks | Input processed | Output | Fable 5 cost |
|---|---|---|---|---|
| Web Platform Parity & Offline | 12 | 9.6B | 36M | $14,400 |
| Communication Platform | 16 | 12.8B | 48M | $19,200 |
| Live Events | 16 | 12.8B | 48M | $19,200 |
| Creator Platform & Marketplace | 29 | 23.2B | 87M | $34,800 |
| Enterprise Trust & Compliance | 20 | 16.0B | 60M | $24,000 |
| Analytics & AI Insights | 18 | 14.4B | 54M | $21,600 |
| Habits & Accountability | 15 | 12.0B | 45M | $18,000 |
| **Full roadmap (through Feb 2028)** | **126** | **~100.8B** | **~378M** | **$151,200** |

Of this, **~77 work-weeks land in the first 12 months** (epics 1–4 complete plus the start of Enterprise Trust, through Jun 27, 2027) ≈ **$92,400** — the basis for the $7,800/mo recommendation above.

## Ongoing AI runtime costs (separate from development)

The AI Growth Insights feature (and existing Claude-powered media tagging) creates **production** API costs independent of development tokens. At launch scale these are small (batchable, Haiku/Sonnet-tier for summarization), but they should get their own line item once member analytics establishes volume. Rough planning figure: $0.01–0.05 per member per month at Sonnet-tier batch pricing.

## Reproducing the measurement

The analysis script sums `message.usage` fields (input, output, cache read/write) from every `*.jsonl` under `~/.claude-home/projects/-Users-lukekeith-www-makeready*`, deduplicated by message id and bucketed by month and model. Re-run it after a few more months of history to tighten the weekly averages.

All levers live in `timeline.json → meta.budget`; per-epic figures are `weeks × $1,200` and reprice automatically with schedule changes.
