/**
 * tag-categories D4 / D11: the tag-category tables ship in ONE Atlas migration that also seeds Books of
 * the Bible — the 66 full book names plus three spelled-out variants, never an abbreviation.
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))
const CREATE = 'CREATE TABLE "tag_category_tags"'

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes(CREATE))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

/** One member per `INSERT INTO "tag_category_tags"` line: its tag, label and position. */
function members(sql: string): { tag: string; label: string; position: number }[] {
  return sql
    .split('\n')
    .filter((line) => line.startsWith('INSERT INTO "tag_category_tags"'))
    .map((line) => {
      const m = line.match(/'([a-z0-9]+)', '([^']+)', (\d+)\) ON CONFLICT DO NOTHING;$/)
      expect(m, line).not.toBeNull()
      return { tag: m![1], label: m![2], position: Number(m![3]) }
    })
}

describe('tag-categories migration (D4, D11)', () => {
  it('creates both tables and seeds the Books of the Bible category', () => {
    const { sql } = findMigration()
    expect(sql).toContain('CREATE TABLE "tag_categories"')
    expect(sql).toContain(`'bible-books', 'Books of the Bible', 1) ON CONFLICT DO NOTHING;`)
  })

  it('seeds 69 spellings over 66 book positions, with no abbreviation', () => {
    const rows = members(findMigration().sql)
    expect(rows).toHaveLength(69)
    expect(new Set(rows.map((r) => r.tag)).size).toBe(69)
    expect(new Set(rows.map((r) => r.position)).size).toBe(66)
    expect(rows.find((r) => r.tag === 'genesis')).toEqual({ tag: 'genesis', label: 'Genesis', position: 1 })
    expect(rows.find((r) => r.tag === '1samuel')).toEqual({ tag: '1samuel', label: '1 Samuel', position: 9 })
    expect(rows.find((r) => r.tag === 'psalm')).toEqual({ tag: 'psalm', label: 'Psalms', position: 19 })
    expect(rows.find((r) => r.tag === 'songofsongs')).toEqual({ tag: 'songofsongs', label: 'Song of Solomon', position: 22 })
    expect(rows.find((r) => r.tag === 'revelations')).toEqual({ tag: 'revelations', label: 'Revelation', position: 66 })
    for (const abbrev of ['gen', 'ex', 'ne', 'ss', 'jn', 'ps', 'song']) {
      expect(rows.find((r) => r.tag === abbrev), abbrev).toBeUndefined()
    }
  })

  it('is listed in atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(file)
  })
})
