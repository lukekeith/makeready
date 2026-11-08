/**
 * text-activity SC12: the lesson arm of `GET /api/search`. A lesson matches by the title or the document text of
 * its searched version - the latest published program version, else its draft; a group's customized version and a
 * deleted lesson never match. The text expressions are the constants the GIN indexes in
 * atlas/migrations/*_text_activity_search_indexes.sql are built on.
 */
import { Prisma, prisma } from '../lib/prisma.js'
import { LESSON_SEARCH_TEXT_SQL, SEARCH_TEXT, qualifySearchExpr } from './master-search-text.js'

export interface LessonSearchRow {
  id: string
  title: string | null
  position: number | null
  programId: string
  programName: string
  coverImageUrl: string | null
  snippet: { text: string; field: string } | null
}

interface LessonRow {
  id: string
  title: string | null
  position: number | null
  program_id: string
  program_name: string
  program_cover_image_url: string | null
  snippet_text: string | null
  snippet_field: string | null
}

// Built on use, not at import: route tests that mock `Prisma` import this module too.
const raw = (sql: string) => Prisma.raw(sql)

/**
 * SQL true for a `lesson_versions` row aliased `alias` when no other program version of its lesson ranks above it:
 * published before draft, then the higher number. A group's customized version (`enrollmentId` set) is never ranked.
 */
export const isSearchedVersion = (alias: string) => `NOT EXISTS (
  SELECT 1 FROM "lesson_versions" better
  WHERE better."lessonId" = ${alias}."lessonId" AND better."enrollmentId" IS NULL
    AND (better."status" = 'PUBLISHED', better."number") > (${alias}."status" = 'PUBLISHED', ${alias}."number"))`

const titleVector = () => raw(qualifySearchExpr(SEARCH_TEXT.lesson, 'v'))
const documentVector = () => raw(qualifySearchExpr(LESSON_SEARCH_TEXT_SQL, 'ca'))
/** The strings LESSON_SEARCH_TEXT_SQL indexes, one row each, for the snippet. */
const documentTexts = () => raw(`jsonb_path_query_array(ca."document", '$.content.objects[*].text') || jsonb_path_query_array(ca."document", '$.content.prompt.text')`)

function mapRow(r: LessonRow): LessonSearchRow {
  return {
    id: r.id,
    title: r.title,
    position: r.position,
    programId: r.program_id,
    programName: r.program_name,
    coverImageUrl: r.program_cover_image_url,
    snippet: r.snippet_text && r.snippet_field ? { text: r.snippet_text, field: r.snippet_field } : null,
  }
}

/**
 * Lessons of the org's active programs whose searched version matches `query`: full text first, then a title
 * substring match (`titleOnly: true`) when that finds nothing, so the caller can build the snippet it has always built.
 */
export async function searchLessons(input: {
  organizationId: string
  query: string
  words: string[]
  limit: number
  cursor?: string
  snippets: boolean
}): Promise<{ items: LessonSearchRow[]; hasMore: boolean; nextCursor: string | null; titleOnly: boolean }> {
  const { organizationId, query, words, limit, cursor, snippets } = input
  const page = (rows: LessonRow[], titleOnly: boolean) => {
    const hasMore = rows.length > limit
    const items = (hasMore ? rows.slice(0, limit) : rows).map(mapRow)
    return { items, hasMore, nextCursor: hasMore ? items[items.length - 1].id : null, titleOnly }
  }

  const select = (join: Prisma.Sql, match: Prisma.Sql, snippet: Prisma.Sql) => Prisma.sql`
    SELECT l."id"::text AS id, v."title" AS title, l."position" AS position, sp."id"::text AS program_id,
      sp."name" AS program_name, sp."coverImageUrl" AS program_cover_image_url, ${snippet}
    FROM "lessons" l
    JOIN "study_programs" sp ON sp."id"::text = l."programId"::text
    JOIN "lesson_versions" v ON v."lessonId"::text = l."id"::text AND v."enrollmentId" IS NULL AND ${raw(isSearchedVersion('v'))}
    ${join}
    WHERE sp."organizationId"::text = ${organizationId} AND sp."isActive" AND l."deletedAt" IS NULL AND ${match}
      ${cursor ? Prisma.sql`AND (l."position", l."id"::text) > ((SELECT "position" FROM "lessons" WHERE "id"::text = ${cursor}), ${cursor})` : Prisma.empty}
    ORDER BY l."position", l."id"
    LIMIT ${limit + 1}`
  const noSnippet = Prisma.sql`NULL::text AS snippet_text, NULL::text AS snippet_field`

  try {
    const tsq = Prisma.sql`plainto_tsquery('english', ${query})`
    const rows = await prisma.$queryRaw<LessonRow[]>(
      snippets
        ? // The best-ranked text among the title and each matching document text is the snippet; no candidate, no match.
          select(
            Prisma.sql`JOIN LATERAL (
              SELECT ts_headline('english', c.matched_text, ${tsq}, 'MaxWords=35, MinWords=15, StartSel=<mark>, StopSel=</mark>') AS snippet_text,
                c.snippet_field
              FROM (
                SELECT v."title" AS matched_text, 'lesson.title' AS snippet_field
                WHERE ${titleVector()} @@ ${tsq}
                UNION ALL
                SELECT t."txt", 'activity.text'
                FROM "content_activities" ca CROSS JOIN LATERAL jsonb_array_elements_text(${documentTexts()}) AS t("txt")
                WHERE ca."lessonVersionId"::text = v."id"::text AND to_tsvector('english', t."txt") @@ ${tsq}
              ) c
              ORDER BY ts_rank(to_tsvector('english', c.matched_text), ${tsq}) DESC
              LIMIT 1
            ) best ON TRUE`,
            Prisma.sql`TRUE`,
            Prisma.sql`best.snippet_text, best.snippet_field`,
          )
        : select(
            Prisma.empty,
            Prisma.sql`(${titleVector()} @@ ${tsq}
              OR EXISTS (SELECT 1 FROM "content_activities" ca WHERE ca."lessonVersionId"::text = v."id"::text AND ${documentVector()} @@ ${tsq}))`,
            noSnippet,
          ),
    )
    if (rows.length > 0 || cursor) return page(rows, false)
  } catch (ftsError) {
    // FTS failed (e.g. all stop words): fall through to the substring match.
    console.warn('Lesson FTS failed, falling back to ILIKE:', ftsError)
  }

  const escape = (word: string) => word.replace(/[\\%_]/g, '\\$&')
  const titleMatch = Prisma.join(words.map((w) => Prisma.sql`v."title" ILIKE ${`%${escape(w)}%`}`), ' AND ')
  return page(await prisma.$queryRaw<LessonRow[]>(select(Prisma.empty, Prisma.sql`(${titleMatch})`, noSnippet)), true)
}
