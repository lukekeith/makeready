import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { assertSearchLease, withTextIdSearchDb } from './helpers/master-search-db.js'
import { SEARCH_TEXT, SEARCH_TITLE, qualifySearchExpr } from '../src/services/master-search-text.js'

const migrations = fileURLToPath(new URL('../atlas/migrations/', import.meta.url))
function readMigration(suffix: string) {
  const files = readdirSync(migrations).filter(name => name.endsWith(suffix))
  expect(files).toHaveLength(1)
  return readFileSync(migrations + files[0], 'utf8')
}

type Key = keyof typeof SEARCH_TEXT
const TABLE: Record<Key, string> = {
  group: 'groups', program: 'study_programs', template: 'lesson_templates', lesson: 'lesson_versions',
  activity: 'content_activities', event: 'events', post: 'posts',
  member: 'members', media: 'media', mediaTag: 'media_tags',
}
const TEXT_INDEX: Record<Key, string> = {
  group: 'groups_search_idx', program: 'study_programs_search_idx', template: 'lesson_templates_search_idx',
  lesson: 'lesson_versions_search_idx', activity: 'content_activities_search_idx',
  event: 'events_search_idx', post: 'posts_search_idx', member: 'members_search_idx', media: 'media_search_idx',
  mediaTag: 'media_tags_search_idx',
}
const TITLE_INDEX: Record<keyof typeof SEARCH_TITLE, string> = {
  group: 'groups_title_lower_idx', program: 'study_programs_title_lower_idx', template: 'lesson_templates_title_lower_idx',
  event: 'events_title_lower_idx', post: 'posts_title_lower_idx',
  member: 'members_title_lower_idx', media: 'media_title_lower_idx',
}

describe('master-search text constants', () => {
  it('every SEARCH_TEXT constant appears verbatim in the migration', () => {
    const sql = readMigration('_master_search_indexes.sql')
    const lessonSql = readMigration('_text_activity_search_indexes.sql')
    for (const [key, expr] of Object.entries(SEARCH_TEXT)) {
      expect(key === 'lesson' || key === 'activity' ? lessonSql : sql).toContain(`gin (${expr})`)
    }
    for (const expr of Object.values(SEARCH_TITLE)) expect(sql).toContain(`(${expr} text_pattern_ops)`)
  })

  it('qualifySearchExpr prefixes every quoted column and leaves literals alone', () => {
    expect(qualifySearchExpr(SEARCH_TEXT.group, 'g')).toBe(
      `to_tsvector('english', coalesce(g."name",'') || ' ' || coalesce(g."description",'') || ' ' || coalesce(g."code",''))`)
    expect(qualifySearchExpr(SEARCH_TITLE.member, 'm')).toBe(
      `lower(btrim(coalesce(m."firstName",'') || ' ' || coalesce(m."lastName",'')))`)
  })
})

describe.skipIf(!process.env.TEST_DATABASE_URL)('master-search indexes', () => {
  let prisma: any
  let pg: import('pg').Client

  beforeAll(async () => {
    const url = assertSearchLease()
    prisma = (await import('../src/lib/prisma.js')).prisma
    const { Client } = await import('pg')
    pg = new Client({ connectionString: url })
    await pg.connect()
    await pg.query('SET enable_seqscan = off')
    await pg.query('SET plan_cache_mode = force_generic_plan')
  })
  afterAll(async () => { await pg?.end() })

  // PREPARE under force_generic_plan: the plan the arm gets after its sixth execution, whatever the value.
  // `without` drops competing indexes inside a transaction that is always rolled back, so the plan shows
  // whether the index under test is usable for the predicate, not whether it wins on whatever stats
  // other test files left on the shared lease.
  async function explain(sql: string, params: string[] = [], without: string[] = []) {
    await pg.query('BEGIN')
    try {
      await pg.query("SET LOCAL lock_timeout = '10s'")
      for (const index of without) await pg.query(`DROP INDEX "${index}"`)
      await pg.query('DEALLOCATE ALL')
      await pg.query(`PREPARE q(${params.map(() => 'text').join(',')}) AS ${sql}`)
      const args = params.map(p => `'${p}'`).join(',')
      const r = await pg.query(`EXPLAIN EXECUTE q(${args})`)
      return r.rows.map((row: any) => row['QUERY PLAN']).join('\n')
    } finally {
      await pg.query('ROLLBACK')
    }
  }

  it('each search and title index exists on the lease', async () => {
    const rows = await prisma.$queryRaw<{ indexname: string }[]>`SELECT indexname FROM pg_indexes WHERE indexname LIKE '%\_search\_idx' OR indexname LIKE '%\_title\_lower\_idx'`
    const names = rows.map((r: { indexname: string }) => r.indexname)
    for (const n of ['groups_search_idx', 'media_tags_search_idx', 'content_activities_search_idx', 'members_title_lower_idx', 'media_title_lower_idx']) expect(names).toContain(n)
    // text-activity SC12 dropped the old lesson indexes (lessons, lesson_activities, activity_read_blocks) and added two.
    for (const n of ['lessons_search_idx', 'lessons_title_lower_idx', 'lesson_activities_search_idx', 'activity_read_blocks_search_idx']) expect(names).not.toContain(n)
    expect(names.filter((n: string) => n.endsWith('_search_idx') && n !== 'verses_search_idx')).toHaveLength(10)
    expect(names.filter((n: string) => n.endsWith('_title_lower_idx'))).toHaveLength(7)
  })

  it('the migration runs on a text-id database', async () => {
    await withTextIdSearchDb(async (url) => {
      const { Client } = await import('pg')
      const client = new Client({ connectionString: url }); await client.connect()
      try {
        // The final model has no old lesson tables; the 1.0 migration indexes them, so give it the columns it names.
        await client.query(`ALTER TABLE "lessons" ADD COLUMN IF NOT EXISTS "title" text;
          CREATE TABLE IF NOT EXISTS "lesson_activities" ("id" text PRIMARY KEY, "title" text, "readContent" text, "helpTitle" text, "helpDescription" text);
          CREATE TABLE IF NOT EXISTS "activity_read_blocks" ("id" text PRIMARY KEY, "title" text, "content" text, "lessonActivityId" text)`)
        await client.query(readMigration('_master_search_indexes.sql'))
        await client.query(readMigration('_text_activity_search_indexes.sql'))
        const r = await client.query(`SELECT indexname FROM pg_indexes WHERE indexname IN ('posts_search_idx', 'lesson_versions_search_idx', 'content_activities_search_idx', 'lessons_search_idx')`)
        expect(r.rows.map((row: { indexname: string }) => row.indexname).sort()).toEqual(['content_activities_search_idx', 'lesson_versions_search_idx', 'posts_search_idx'])
      } finally { await client.end() }
    })
  }, 180_000)

  it('the migration can be applied twice', async () => {
    await pg.query(readMigration('_master_search_indexes.sql'))
    await pg.query(readMigration('_text_activity_search_indexes.sql'))
  })

  it.each(Object.entries(TEXT_INDEX))('EXPLAIN uses the text index for %s', async (key, index) => {
    const k = key as Key
    const config = k === 'member' ? 'simple' : 'english'
    // mediaTag: the btree on "tag" (idx_media_tags_tag) can be scanned in full with the tsquery as its filter, and on a
    // small table that can beat the GIN index (the verifier saw this fail once, with a green run at the same sha).
    const without = k === 'mediaTag' ? ['idx_media_tags_tag'] : []
    const plan = await explain(`SELECT 1 FROM "${TABLE[k]}" WHERE ${SEARCH_TEXT[k]} @@ to_tsquery('${config}', $1)`, ['grace:*'], without)
    expect(plan).toContain(index)
  })

  // F14: a parameterized `LIKE $1` plans as a Seq Scan under a generic plan, so a prefix is a range
  // over the text_pattern_ops operators (`~>=~`, `~<~`) with the upper bound computed by the caller.
  it.each(Object.entries(TITLE_INDEX))('EXPLAIN uses the title index for %s on a parameterized prefix range', async (key, index) => {
    const k = key as keyof typeof SEARCH_TITLE
    const plan = await explain(`SELECT 1 FROM "${TABLE[k]}" WHERE ${SEARCH_TITLE[k]} ~>=~ $1 AND ${SEARCH_TITLE[k]} ~<~ $2`, ['grace', 'gracf'])
    expect(plan).toContain(index)
  })

  it.each(Object.entries(TITLE_INDEX))('EXPLAIN uses the title index for %s on an exact title', async (key, index) => {
    const k = key as keyof typeof SEARCH_TITLE
    const plan = await explain(`SELECT 1 FROM "${TABLE[k]}" WHERE ${SEARCH_TITLE[k]} = $1`, ['grace'])
    expect(plan).toContain(index)
  })
})
