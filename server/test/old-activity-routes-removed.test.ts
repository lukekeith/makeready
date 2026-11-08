/**
 * text-activity SC8: the 1.0 activity, theme, member-lesson, study-preview and scheduled-activity routes
 * are gone. A removed route falls through to Express's own 404 (an empty JSON body under supertest), so a
 * handler that is still mounted and answers its own 404 JSON ("Activity not found") fails these cases.
 *
 * Sent with no credentials: a still-mounted handler behind requireAuth answers 401, which fails the 404
 * check just as surely, and a removed route never reaches auth. (A bearer key made the case depend on the
 * key lookup — the merge tier saw one request of ~70 answer 401 on it.)
 */
import { describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'

const ID = '00000000-0000-4000-8000-000000000000'

describe('the removed routes are gone', () => {
  it.each([
    // themes.ts
    ['get', '/api/themes'],
    ['get', '/api/themes/public/list'],
    ['get', `/api/themes/${ID}`],
    // programs.ts: lesson activities, preview-data, source references, highlights, read blocks
    ['get', `/api/programs/${ID}/preview-data`],
    ['get', `/api/lessons/${ID}/preview-data`],
    ['get', `/api/activities/${ID}/preview-data`],
    ['post', `/api/programs/${ID}/lessons/${ID}/activities`],
    ['post', `/api/programs/${ID}/lessons/${ID}/reorder-activities`],
    ['patch', `/api/activities/${ID}`],
    ['delete', `/api/activities/${ID}`],
    ['post', `/api/activities/${ID}/reset`],
    ['post', `/api/activities/${ID}/source-references`],
    ['delete', `/api/activities/${ID}/source-references/${ID}`],
    ['get', `/api/activities/${ID}/highlights`],
    ['get', `/api/activities/${ID}/exegesis-highlights`],
    ['post', `/api/activities/${ID}/highlights`],
    ['post', `/api/activities/${ID}/exegesis-highlights`],
    ['patch', `/api/activities/${ID}/highlights/${ID}`],
    ['patch', `/api/activities/${ID}/exegesis-highlights/${ID}`],
    ['delete', `/api/activities/${ID}/highlights/${ID}`],
    ['delete', `/api/activities/${ID}/exegesis-highlights/${ID}`],
    ['post', `/api/activities/${ID}/read-blocks`],
    ['patch', `/api/activities/${ID}/read-blocks/reorder`],
    ['patch', `/api/activities/${ID}/read-blocks/${ID}`],
    ['delete', `/api/activities/${ID}/read-blocks/${ID}`],
    // enrollments.ts: member lesson views and scheduled activities
    ['get', '/api/lessons/code/ABC123'],
    ['get', `/api/lessons/view/${ID}`],
    ['get', `/api/lessons/today/${ID}`],
    ['patch', `/api/scheduled-activities/${ID}`],
    ['get', `/api/enrollments/${ID}/schedules/${ID}/activities`],
    ['post', `/api/enrollments/${ID}/schedules/${ID}/activities`],
    ['post', `/api/enrollments/${ID}/schedules/${ID}/reorder-activities`],
    ['delete', `/api/scheduled-activities/${ID}`],
    ['post', `/api/scheduled-activities/${ID}/reset`],
    ['post', `/api/scheduled-activities/${ID}/source-references`],
    ['delete', `/api/scheduled-activities/${ID}/source-references/${ID}`],
    ['post', `/api/scheduled-activities/${ID}/read-blocks`],
    ['patch', `/api/scheduled-activities/${ID}/read-blocks/reorder`],
    ['patch', `/api/scheduled-activities/${ID}/read-blocks/${ID}`],
    ['delete', `/api/scheduled-activities/${ID}/read-blocks/${ID}`],
    ['get', `/api/scheduled-activities/${ID}/highlights`],
    ['get', `/api/scheduled-activities/${ID}/exegesis-highlights`],
    ['post', `/api/scheduled-activities/${ID}/highlights`],
    ['patch', `/api/scheduled-activities/${ID}/highlights/${ID}`],
    ['delete', `/api/scheduled-activities/${ID}/exegesis-highlights/${ID}`],
    // member-lessons.ts
    ['get', '/api/member/lessons'],
    ['get', `/api/member/lessons/${ID}`],
    ['get', `/api/member/lessons/${ID}/summary`],
    ['get', '/api/member/enrollments'],
    ['get', `/api/member/enrollments/${ID}`],
    ['get', `/api/member/groups/${ID}/studies`],
    // activity-progress.ts
    ['post', `/api/member/activities/${ID}/progress`],
    ['get', `/api/member/activities/${ID}/progress`],
    ['post', `/api/member/activities/${ID}/submit`],
    ['post', `/api/activities/${ID}/progress`],
    ['post', `/api/member/activities/${ID}/video-progress`],
    ['get', `/api/member/activities/${ID}/video-progress`],
    ['post', `/api/member/activities/${ID}/exegesis-visit`],
    // study-preview.ts
    ['post', '/api/study-preview'],
    ['get', '/public/preview/sometoken'],
    ['get', `/public/preview/sometoken/lesson/${ID}`],
    ['get', `/public/preview/sometoken/activity/${ID}`],
    ['post', `/api/preview/sometoken/state/note/${ID}`],
    ['post', `/api/preview/sometoken/state/lesson-complete/${ID}`],
  ])('%s %s is gone', async (method, path) => {
    const res = await (request(app) as any)[method](path)
    expect(res.status).toBe(404)
    expect(res.body).toEqual({})
  })
})
