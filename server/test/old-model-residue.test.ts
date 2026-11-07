import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, resolve } from 'node:path'

const root = resolve(__dirname, '..')
const OLD =
  /prisma\.(lessonActivity|scheduledLessonActivity|activityReadBlock|contentHighlight|activitySourceReference|textTheme|lessonSchedule|lessonScheduleVersion|memberActivityProgress|memberVideoProgress|memberLessonProgress|studyProgramVersion|enrollmentSyncRun)\b|tx\.(lessonActivity|lessonSchedule|textTheme)\b/

function walk(dirs: string[]): string[] {
  const out: string[] = []
  const visit = (p: string) => {
    for (const name of readdirSync(p)) {
      if (name === 'node_modules' || name === 'generated') continue
      const full = join(p, name)
      if (statSync(full).isDirectory()) visit(full)
      else if (/\.(ts|js|mjs)$/.test(name)) out.push(full)
    }
  }
  for (const d of dirs) visit(join(root, d))
  return out
}

describe('residual sweep (SC8)', () => {
  it('no old-model accessor remains outside fixtures', () => {
    const hits = walk(['src', 'scripts', 'prisma', 'test']).filter(f => OLD.test(readFileSync(f, 'utf8')))
    expect(hits.filter(f => !f.endsWith('old-model-residue.test.ts')).map(f => f.replace(root + '/', ''))).toEqual([])
  })

  it('the deleted lesson-content-hash service and backfill scripts are gone', () => {
    const all = walk(['src', 'scripts', 'prisma', 'test']).map(f => f.replace(root + '/', ''))
    expect(all.filter(f => /lesson-content-hash|backfill-study-sync|backfill-lesson-estimates|backfill-highlights|load-themes/.test(f))).toEqual([])
  })
})
