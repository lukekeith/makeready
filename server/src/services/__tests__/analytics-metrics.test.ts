import { describe, expect, it } from 'vitest'
import { DERIVED_EVENT_TYPES, METRICS_BY_NAME } from '../analytics-metrics.js'
import { AnalyticsQueryError, runAnalyticsQuery } from '../analytics.service.js'

describe('scheduled_lessons registry entry (home-dashboard-data D10, D14)', () => {
  it('is a derived event type', () => {
    expect(DERIVED_EVENT_TYPES).toContain('LESSON_SCHEDULED')
  })

  it('is registered as a current-only flow count bucketed by stored date', () => {
    const m = METRICS_BY_NAME.get('scheduled_lessons')
    expect(m).toMatchObject({
      name: 'scheduled_lessons',
      format: 'count',
      type: 'simple',
      class: 'flow',
      versionSemantics: 'current-only',
      eventTypes: ['LESSON_SCHEDULED'],
      agg: 'count',
      dimensionsAllowed: true,
      dateBucket: 'stored_date',
    })
  })

  it('leaves every existing metric on local (event-time) bucketing', () => {
    for (const [name, m] of METRICS_BY_NAME) {
      if (name !== 'scheduled_lessons') expect(m.dateBucket ?? 'local').toBe('local')
    }
  })

  it('refuses to mix stored-date and event-time metrics in one query (400, before any DB access)', async () => {
    const query = runAnalyticsQuery(
      {
        metrics: ['scheduled_lessons', 'lesson_completions'],
        dimensions: ['day'],
        filters: { from: '2026-10-01', to: '2026-10-07' },
        timezone: 'UTC',
      },
      { all: true }
    )
    await expect(query).rejects.toBeInstanceOf(AnalyticsQueryError)
    await expect(query).rejects.toMatchObject({
      status: 400,
      message: 'Metric(s) scheduled_lessons bucket by stored date and cannot be combined with event-time metrics',
    })
  })
})
