import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { parse } from 'yaml'
import { FIXTURES_DIR } from '../runner.js'

// staging-fixtures D10, D8, F2: the nightly and manual reset's fixed values.
const wf = parse(readFileSync(join(FIXTURES_DIR, '../../.github/workflows/reset-staging-fixtures.yml'), 'utf8'))
const job = wf.jobs.reset

describe('reset-staging-fixtures workflow', () => {
  it('the workflow runs nightly and by hand with the three inputs', () => {
    expect(wf.on.schedule).toEqual([{ cron: '0 8 * * *' }])
    expect(wf.on.workflow_dispatch.inputs.fixture.options).toEqual(['full', 'new-group', 'all'])
  })
  it('runs never overlap and the job is bounded', () => {
    expect(wf.concurrency).toEqual({ group: 'reset-staging-fixtures', 'cancel-in-progress': false })
    expect(job['timeout-minutes']).toBe(30)
  })
  it('it targets staging with images on in its own bucket and only staging secrets', () => {
    expect(job.env.FIXTURES_TARGET).toBe('staging')
    expect(job.env.NODE_ENV).toBe('development')
    expect(job.env.FIXTURE_IMAGES).toBe('on')
    expect(job.env.R2_BUCKET_NAME).toBe('makeready-staging')
    expect(job.env.R2_SECRET_ACCESS_KEY).toBe('${{ secrets.STAGING_R2_SECRET_ACCESS_KEY }}')
    expect(job.env.DATABASE_URL).toBe('${{ secrets.STAGING_DATABASE_URL }}')
    expect(job.env.DIRECT_URL).toBe('${{ secrets.STAGING_DIRECT_URL }}')
    expect(JSON.stringify(wf)).not.toContain('PRODUCTION_')
  })
  it('every step after the secrets check is skipped on a scheduled skip', () => {
    const steps = job.steps as Array<{ id?: string; if?: string; run?: string }>
    expect(steps[0].id).toBe('secrets')
    expect(steps[0].run).toContain('schedule')
    for (const step of steps.slice(1)) expect(step.if).toBe("steps.secrets.outputs.skip != 'true'")
  })
})
