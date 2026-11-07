import { Router } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { parseReference, getSearchType, matchBookNames } from '../utils/bible-reference-parser.js'
import { requireAuth } from '../middleware/auth.js'
import { searchLessons } from '../services/lesson-search.js'
import { SEARCH_TYPES, SearchParamError, parseListFilters, parseRankedParams, parseRecentLimit } from '../services/master-search-query.js'
import { deleteRecentResult, listRecentResults, recordRecentResult, searchFilterOptions, searchRanked } from '../services/master-search.js'

const router = Router()

// ============================================
// UNIFIED SEARCH - Cross-resource search
// ============================================

const VALID_TYPES = [
  'GROUP',
  'PROGRAM',
  'TEMPLATE',
  'VIDEO',
  'EVENT',
  'POST',
  'MEMBER',
  'LESSON',
] as const

type SearchType = (typeof VALID_TYPES)[number]

const searchQuerySchema = z.object({
  q: z.string().min(1),
  types: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(50).optional().default(5),
  organizationId: z.string().uuid().optional(),
  snippets: z.enum(['true', 'false']).optional().default('false'),
  links: z.string().optional().default('false'),
  cursor: z.string().uuid().optional(),
})

/** Generic linked context attached to search results */
interface SearchResultLink {
  type: 'PROGRAM' | 'LESSON' | 'GROUP'
  id: string
  name: string
  imageUrl?: string | null
}

/** Linkable result types */
const LINKABLE_TYPES = ['VIDEO', 'LESSON', 'EVENT', 'POST'] as const
type LinkableType = (typeof LINKABLE_TYPES)[number]

/** Parse the `links` query param into a set of types that should get links */
function parseLinksParam(value: string): Set<LinkableType> {
  if (value === 'false') return new Set()
  if (value === 'true') return new Set(LINKABLE_TYPES)
  const types = value.split(',').map((t) => t.trim().toUpperCase())
  const valid = types.filter((t) =>
    (LINKABLE_TYPES as readonly string[]).includes(t)
  )
  return new Set(valid as LinkableType[])
}

/**
 * Build word-match AND conditions:
 * Every word must appear in at least one of the searchable fields.
 */
function wordMatchConditions(
  words: string[],
  fields: string[]
): Record<string, unknown>[] {
  return words.map((word) => ({
    OR: fields.map((field) => ({
      [field]: { contains: word, mode: 'insensitive' },
    })),
  }))
}

/**
 * Generate a snippet with <mark> highlighted matches for ILIKE-based results.
 * Returns the first field that contains a match, truncated to ~200 chars around it.
 */
function generateIlikeSnippet(
  record: Record<string, unknown>,
  fields: { key: string; label: string }[],
  words: string[]
): { text: string; field: string } | null {
  for (const { key, label } of fields) {
    const value = record[key]
    if (typeof value !== 'string' || !value) continue

    // Check if any word matches (case-insensitive)
    const lowerValue = value.toLowerCase()
    const matchedWord = words.find((w) => lowerValue.includes(w.toLowerCase()))
    if (!matchedWord) continue

    // Truncate around the first match
    const matchIndex = lowerValue.indexOf(matchedWord.toLowerCase())
    const contextChars = 100
    const start = Math.max(0, matchIndex - contextChars)
    const end = Math.min(value.length, matchIndex + matchedWord.length + contextChars)
    let snippet = value.slice(start, end)
    if (start > 0) snippet = '...' + snippet
    if (end < value.length) snippet = snippet + '...'

    // Wrap ALL matching words in <mark> tags (case-insensitive)
    for (const word of words) {
      const escaped = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
      snippet = snippet.replace(
        new RegExp(`(${escaped})`, 'gi'),
        '<mark>$1</mark>'
      )
    }

    return { text: snippet, field: label }
  }
  return null
}

/** Paginated searcher result */
interface SearcherResult {
  items: unknown[]
  hasMore: boolean
  nextCursor: string | null
}

/**
 * @openapi
 * /api/search:
 *   get:
 *     tags: [Search]
 *     summary: Unified search across all resource types
 *     description: |
 *       Searches across groups, programs, templates, videos, events, posts, members, and lessons
 *       using split-word AND matching. All words in the query must appear (in any order) across
 *       the resource's searchable fields.
 *
 *       Example: "3 Day" matches "Day 3 of John" because both "3" and "Day" appear.
 *     security:
 *       - session: []
 *       - apiKey: []
 *     parameters:
 *       - in: query
 *         name: q
 *         required: true
 *         schema:
 *           type: string
 *         description: Search query (split into words, all must match)
 *       - in: query
 *         name: types
 *         required: false
 *         schema:
 *           type: string
 *         description: "Comma-separated resource types: GROUP,PROGRAM,TEMPLATE,VIDEO,EVENT,POST,MEMBER,LESSON"
 *       - in: query
 *         name: limit
 *         required: false
 *         schema:
 *           type: integer
 *           default: 5
 *           minimum: 1
 *           maximum: 50
 *         description: Maximum results per resource type
 *       - in: query
 *         name: organizationId
 *         required: false
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Override organization scope (API key auth only)
 *       - in: query
 *         name: snippets
 *         required: false
 *         schema:
 *           type: string
 *           enum: ["true", "false"]
 *           default: "false"
 *         description: Include highlighted snippet per result showing why it matched
 *       - in: query
 *         name: links
 *         required: false
 *         schema:
 *           type: string
 *           default: "false"
 *         description: |
 *           Attach linked context to results. Values: "true" (all linkable types),
 *           "false" (none), or comma-separated types like "VIDEO,LESSON".
 *           Supported: VIDEO (gets LESSON+PROGRAM links), LESSON (PROGRAM),
 *           EVENT (GROUP), POST (GROUP). Each link has type, id, name, and optional imageUrl.
 *       - in: query
 *         name: cursor
 *         required: false
 *         schema:
 *           type: string
 *           format: uuid
 *         description: |
 *           ID of the last item from the previous page for cursor-based pagination.
 *           Omit for the first page. Requires exactly one type in the types parameter.
 *     responses:
 *       200:
 *         description: Search results grouped by type with pagination metadata
 *       400:
 *         description: Invalid request parameters
 *       401:
 *         description: Not authenticated
 */
router.get('/', requireAuth, async (req, res) => {
  try {
    const parsed = searchQuerySchema.safeParse(req.query)
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid search parameters',
        details: parsed.error.flatten().fieldErrors,
      })
    }

    const { q, types: typesParam, limit, snippets: snippetsParam, links: linksParam, cursor } = parsed.data
    const wantSnippets = snippetsParam === 'true'
    const linkTypes = parseLinksParam(linksParam)

    // Split query into words, filter empty
    const words = q.trim().split(/\s+/).filter(Boolean)
    if (words.length === 0) {
      return res.status(400).json({ success: false, error: 'Query is empty' })
    }

    // Parse requested types
    let requestedTypes: SearchType[]
    if (typesParam) {
      const raw = typesParam.split(',').map((t) => t.trim().toUpperCase())
      const invalid = raw.filter(
        (t) => !VALID_TYPES.includes(t as SearchType)
      )
      if (invalid.length > 0) {
        return res
          .status(400)
          .json({ success: false, error: `Invalid types: ${invalid.join(', ')}` })
      }
      requestedTypes = raw as SearchType[]
    } else {
      requestedTypes = [...VALID_TYPES]
    }

    // Cursor requires exactly one type
    if (cursor && requestedTypes.length !== 1) {
      return res.status(400).json({
        success: false,
        error: 'cursor requires exactly one type (e.g. types=VIDEO)',
      })
    }

    // Determine organization scope
    const userId = (req.user as any).id
    let organizationId: string | undefined

    // API key auth can override organizationId
    if (req.apiKeyId && parsed.data.organizationId) {
      organizationId = parsed.data.organizationId
    }

    // Default: find the org owned by this user
    if (!organizationId) {
      const org = await prisma.organization.findFirst({
        where: { ownerId: userId, isActive: true },
        select: { id: true },
      })
      organizationId = org?.id
    }

    if (!organizationId) {
      return res
        .status(400)
        .json({ success: false, error: 'No organization found for user' })
    }

    // Helper: apply take+1 / hasMore / nextCursor pattern to Prisma results
    const cursorForType = (type: SearchType) =>
      cursor && requestedTypes.length === 1 && requestedTypes[0] === type
        ? cursor
        : undefined

    function paginateResults(rows: { id: string }[]): SearcherResult {
      const hasMore = rows.length > limit
      const items = hasMore ? rows.slice(0, limit) : rows
      const nextCursor = hasMore ? items[items.length - 1].id : null
      return { items, hasMore, nextCursor }
    }

    // Build searchers - only for requested types
    // ILIKE searchers attach snippets in a post-processing step (no extra DB queries)
    const searchers: Record<string, () => Promise<SearcherResult>> = {
      GROUP: async () => {
        const c = cursorForType('GROUP')
        const rows = await prisma.group.findMany({
          where: {
            organizationId,
            isActive: true,
            AND: wordMatchConditions(words, ['name', 'description', 'code']),
          },
          select: {
            id: true,
            name: true,
            description: true,
            code: true,
            coverImageUrl: true,
            createdAt: true,
          },
          take: limit + 1,
          orderBy: { createdAt: 'desc' },
          ...(c && { cursor: { id: c }, skip: 1 }),
        })
        const { items, hasMore, nextCursor } = paginateResults(rows)
        const mapped = wantSnippets
          ? (items as typeof rows).map((r) => ({
              ...r,
              snippet: generateIlikeSnippet(r as Record<string, unknown>, [
                { key: 'name', label: 'name' },
                { key: 'description', label: 'description' },
                { key: 'code', label: 'code' },
              ], words),
            }))
          : items
        return { items: mapped, hasMore, nextCursor }
      },

      PROGRAM: async () => {
        const c = cursorForType('PROGRAM')
        const rows = await prisma.studyProgram.findMany({
          where: {
            organizationId,
            isActive: true,
            AND: wordMatchConditions(words, ['name', 'description']),
          },
          select: {
            id: true,
            name: true,
            description: true,
            coverImageUrl: true,
            isPublished: true,
            days: true,
            createdAt: true,
          },
          take: limit + 1,
          orderBy: { createdAt: 'desc' },
          ...(c && { cursor: { id: c }, skip: 1 }),
        })
        const { items, hasMore, nextCursor } = paginateResults(rows)
        const mapped = wantSnippets
          ? (items as typeof rows).map((r) => ({
              ...r,
              snippet: generateIlikeSnippet(r as Record<string, unknown>, [
                { key: 'name', label: 'name' },
                { key: 'description', label: 'description' },
              ], words),
            }))
          : items
        return { items: mapped, hasMore, nextCursor }
      },

      TEMPLATE: async () => {
        const c = cursorForType('TEMPLATE')
        const rows = await prisma.lessonTemplate.findMany({
          where: {
            OR: [{ organizationId }, { isSystem: true }],
            isActive: true,
            AND: wordMatchConditions(words, ['name', 'description']),
          },
          select: {
            id: true,
            name: true,
            description: true,
            isSystem: true,
            createdAt: true,
          },
          take: limit + 1,
          orderBy: { createdAt: 'desc' },
          ...(c && { cursor: { id: c }, skip: 1 }),
        })
        const { items, hasMore, nextCursor } = paginateResults(rows)
        const mapped = wantSnippets
          ? (items as typeof rows).map((r) => ({
              ...r,
              snippet: generateIlikeSnippet(r as Record<string, unknown>, [
                { key: 'name', label: 'name' },
                { key: 'description', label: 'description' },
              ], words),
            }))
          : items
        return { items: mapped, hasMore, nextCursor }
      },

      VIDEO: async () => {
        const wantVideoLinks = linkTypes.has('VIDEO')
        const c = cursorForType('VIDEO')
        const rows = await prisma.video.findMany({
          where: {
            userId,
            isActive: true,
            AND: wordMatchConditions(words, ['title', 'description']),
          },
          select: {
            id: true,
            title: true,
            description: true,
            thumbnailUrl: true,
            playbackUrl: true,
            status: true,
            duration: true,
            createdAt: true,
          },
          take: limit + 1,
          orderBy: { createdAt: 'desc' },
          ...(c && { cursor: { id: c }, skip: 1 }),
        })

        // Batch fetch lesson/program links for video results
        let videoLinksMap: Map<string, SearchResultLink[]> | undefined
        if (wantVideoLinks && rows.length > 0) {
          const videoIds = rows.map((r) => r.id)
          // D34: a document's videoId is tracked through Media.videoId and
          // MediaUsage rows (usageType ACTIVITY, resourceId = activityKey).
          const mediaRows = await prisma.media.findMany({
            where: { videoId: { in: videoIds } },
            select: { id: true, videoId: true },
          })
          const videoIdByMediaId = new Map(mediaRows.map((m) => [m.id, m.videoId as string]))
          const usages = mediaRows.length
            ? await prisma.mediaUsage.findMany({
                where: { mediaId: { in: mediaRows.map((m) => m.id) }, usageType: 'ACTIVITY' },
                select: { mediaId: true, resourceId: true },
              })
            : []
          const videoIdsByActivityKey = new Map<string, Set<string>>()
          for (const u of usages) {
            const set = videoIdsByActivityKey.get(u.resourceId) || new Set<string>()
            set.add(videoIdByMediaId.get(u.mediaId)!)
            videoIdsByActivityKey.set(u.resourceId, set)
          }
          const activities = usages.length
            ? await prisma.contentActivity.findMany({
                where: {
                  activityKey: { in: [...videoIdsByActivityKey.keys()] },
                  lessonVersion: { lesson: { deletedAt: null, program: { isActive: true } } },
                },
                select: {
                  activityKey: true,
                  lessonVersion: {
                    select: {
                      title: true,
                      lesson: {
                        select: {
                          id: true,
                          program: { select: { id: true, name: true, coverImageUrl: true } },
                        },
                      },
                    },
                  },
                },
              })
            : []
          videoLinksMap = new Map<string, SearchResultLink[]>()
          for (const act of activities) {
            const lesson = act.lessonVersion.lesson
            const program = lesson.program
            if (!program) continue
            for (const videoId of videoIdsByActivityKey.get(act.activityKey) ?? []) {
              const existing = videoLinksMap.get(videoId) || []
              const lessonKey = `LESSON:${lesson.id}`
              const programKey = `PROGRAM:${program.id}`
              const seen = new Set(existing.map((l) => `${l.type}:${l.id}`))
              if (!seen.has(lessonKey)) {
                existing.push({ type: 'LESSON', id: lesson.id, name: act.lessonVersion.title || 'Untitled', imageUrl: null })
              }
              if (!seen.has(programKey)) {
                existing.push({ type: 'PROGRAM', id: program.id, name: program.name, imageUrl: program.coverImageUrl })
              }
              videoLinksMap.set(videoId, existing)
            }
          }
        }

        const { items, hasMore, nextCursor } = paginateResults(rows)
        const mapped = (items as typeof rows).map((r) => ({
          ...r,
          ...(wantSnippets && {
            snippet: generateIlikeSnippet(r as Record<string, unknown>, [
              { key: 'title', label: 'title' },
              { key: 'description', label: 'description' },
            ], words),
          }),
          ...(videoLinksMap && {
            links: videoLinksMap.get(r.id) || [],
          }),
        }))
        return { items: mapped, hasMore, nextCursor }
      },

      EVENT: async () => {
        const wantEventLinks = linkTypes.has('EVENT')
        const c = cursorForType('EVENT')
        const rows = await prisma.event.findMany({
          where: {
            group: { organizationId, isActive: true },
            isActive: true,
            AND: wordMatchConditions(words, [
              'title',
              'description',
              'locationName',
            ]),
          },
          select: {
            id: true,
            title: true,
            description: true,
            coverImageUrl: true,
            date: true,
            locationName: true,
            type: true,
            createdAt: true,
            ...(wantEventLinks && {
              group: { select: { id: true, name: true, coverImageUrl: true } },
            }),
          },
          take: limit + 1,
          orderBy: { date: 'desc' },
          ...(c && { cursor: { id: c }, skip: 1 }),
        })
        const { items, hasMore, nextCursor } = paginateResults(rows as { id: string }[])
        const mapped = (items as typeof rows).map((r) => {
          const { group, ...rest } = r as typeof r & { group?: { id: string; name: string; coverImageUrl: string | null } }
          return {
            ...rest,
            ...(wantSnippets && {
              snippet: generateIlikeSnippet(rest as Record<string, unknown>, [
                { key: 'title', label: 'title' },
                { key: 'description', label: 'description' },
                { key: 'locationName', label: 'locationName' },
              ], words),
            }),
            ...(wantEventLinks && group && {
              links: [{ type: 'GROUP' as const, id: group.id, name: group.name, imageUrl: group.coverImageUrl }],
            }),
          }
        })
        return { items: mapped, hasMore, nextCursor }
      },

      POST: async () => {
        const wantPostLinks = linkTypes.has('POST')
        const c = cursorForType('POST')
        const rows = await prisma.post.findMany({
          where: {
            group: { organizationId, isActive: true },
            isActive: true,
            AND: wordMatchConditions(words, ['title', 'content']),
          },
          select: {
            id: true,
            title: true,
            content: true,
            imageUrl: true,
            type: true,
            createdAt: true,
            ...(wantPostLinks && {
              group: { select: { id: true, name: true, coverImageUrl: true } },
            }),
          },
          take: limit + 1,
          orderBy: { createdAt: 'desc' },
          ...(c && { cursor: { id: c }, skip: 1 }),
        })
        const { items, hasMore, nextCursor } = paginateResults(rows as { id: string }[])
        const mapped = (items as typeof rows).map((r) => {
          const { group, ...rest } = r as typeof r & { group?: { id: string; name: string; coverImageUrl: string | null } }
          return {
            ...rest,
            ...(wantSnippets && {
              snippet: generateIlikeSnippet(rest as Record<string, unknown>, [
                { key: 'title', label: 'title' },
                { key: 'content', label: 'content' },
              ], words),
            }),
            ...(wantPostLinks && group && {
              links: [{ type: 'GROUP' as const, id: group.id, name: group.name, imageUrl: group.coverImageUrl }],
            }),
          }
        })
        return { items: mapped, hasMore, nextCursor }
      },

      MEMBER: async () => {
        const c = cursorForType('MEMBER')
        const rows = await prisma.member.findMany({
          where: {
            isActive: true,
            organizations: { some: { organizationId } },
            AND: wordMatchConditions(words, [
              'firstName',
              'lastName',
              'email',
              'phoneNumber',
            ]),
          },
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            phoneNumber: true,
            profilePicture: true,
          },
          take: limit + 1,
          orderBy: { firstName: 'asc' },
          ...(c && { cursor: { id: c }, skip: 1 }),
        })
        const { items, hasMore, nextCursor } = paginateResults(rows)
        const mapped = wantSnippets
          ? (items as typeof rows).map((r) => ({
              ...r,
              snippet: generateIlikeSnippet(r as Record<string, unknown>, [
                { key: 'firstName', label: 'firstName' },
                { key: 'lastName', label: 'lastName' },
                { key: 'email', label: 'email' },
                { key: 'phoneNumber', label: 'phoneNumber' },
              ], words),
            }))
          : items
        return { items: mapped, hasMore, nextCursor }
      },

      LESSON: async () => {
        const wantLessonLinks = linkTypes.has('LESSON')
        const found = await searchLessons({
          organizationId: organizationId as string,
          query: q.trim(),
          words,
          limit,
          cursor: cursorForType('LESSON'),
          snippets: wantSnippets,
        })
        const items = found.items.map((r) => ({
          id: r.id,
          title: r.title,
          dayNumber: r.position,
          studyProgramId: r.programId,
          studyProgram: { name: r.programName, coverImageUrl: r.coverImageUrl },
          ...(wantSnippets && {
            snippet: found.titleOnly
              ? generateIlikeSnippet({ title: r.title }, [{ key: 'title', label: 'lesson.title' }], words)
              : r.snippet,
          }),
          ...(wantLessonLinks && {
            links: [{ type: 'PROGRAM' as const, id: r.programId, name: r.programName, imageUrl: r.coverImageUrl }],
          }),
        }))
        return { items, hasMore: found.hasMore, nextCursor: found.nextCursor }
      },
    }

    // Run only requested searches in parallel
    const entries = requestedTypes.filter((t) => searchers[t])
    const searchResults = await Promise.all(
      entries.map((type) => searchers[type]())
    )

    // Map type names to plural keys
    const keyMap: Record<SearchType, string> = {
      GROUP: 'groups',
      PROGRAM: 'programs',
      TEMPLATE: 'templates',
      VIDEO: 'videos',
      EVENT: 'events',
      POST: 'posts',
      MEMBER: 'members',
      LESSON: 'lessons',
    }

    const results: Record<string, unknown[]> = {}
    const counts: Record<string, number> = {}
    const pagination: Record<string, { hasMore: boolean; nextCursor: string | null }> = {}
    let total = 0

    entries.forEach((type, i) => {
      const key = keyMap[type]
      const result = searchResults[i]
      results[key] = result.items
      counts[key] = result.items.length
      total += result.items.length
      pagination[key] = { hasMore: result.hasMore, nextCursor: result.nextCursor }
    })

    // Fill in empty arrays for non-requested types
    for (const type of VALID_TYPES) {
      const key = keyMap[type]
      if (!(key in results)) {
        results[key] = []
        counts[key] = 0
        pagination[key] = { hasMore: false, nextCursor: null }
      }
    }
    counts.total = total

    res.json({
      success: true,
      query: q,
      results,
      counts,
      pagination,
    })
  } catch (error) {
    console.error('Unified search error:', error)
    res.status(500).json({ success: false, error: 'Search failed' })
  }
})

// ============================================
// SMART SEARCH - Handles both direct refs and semantic search
// ============================================

/**
 * @openapi
 * /api/search/smart:
 *   post:
 *     tags: [Search]
 *     summary: Smart search for Bible verses
 *     description: |
 *       Unified search endpoint that automatically detects the query type and routes accordingly:
 *       - **Direct references** (e.g., "Romans 1:1", "John 3:16-17", "Psalm 23") → exact verse/chapter lookup via API.Bible
 *       - **Concept queries** (e.g., "overcoming fear", "forgiveness") → semantic search over locally-stored
 *         verses using pgvector embeddings (bge-small-en-v1.5). Matching runs against the public-domain WEB
 *         translation; verse text is then resolved in the requested translation (local table or cached
 *         API.Bible chapter fetch). Verses that can't be resolved keep WEB text and carry a per-verse
 *         `sourceTranslation: "WEB"` marker. Falls back to API.Bible keyword search if embeddings are
 *         unavailable (EMBEDDINGS_ENABLED=false or backfill not run).
 *
 *       Direct references use chapter-first caching — the entire chapter is cached on first access.
 *       Default translation is NASB, or the user's preferred translation if authenticated.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - query
 *             properties:
 *               query:
 *                 type: string
 *                 description: Bible reference (e.g., "John 3:16") or search keywords (e.g., "love")
 *                 example: "John 3:16"
 *               translation:
 *                 type: string
 *                 description: Translation code
 *                 default: "NASB"
 *               limit:
 *                 type: integer
 *                 description: Maximum results for keyword search
 *                 default: 10
 *                 maximum: 100
 *     responses:
 *       200:
 *         description: Search results — shape varies by query type
 *         content:
 *           application/json:
 *             schema:
 *               oneOf:
 *                 - type: object
 *                   description: Direct reference result
 *                   properties:
 *                     type:
 *                       type: string
 *                       enum: [direct]
 *                     query:
 *                       type: string
 *                     translation:
 *                       type: string
 *                     book:
 *                       type: object
 *                       properties:
 *                         bookNumber:
 *                           type: integer
 *                         name:
 *                           type: string
 *                         abbrev:
 *                           type: string
 *                     chapter:
 *                       type: integer
 *                     verses:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           verse:
 *                             type: integer
 *                           text:
 *                             type: string
 *                           reference:
 *                             type: string
 *                     total:
 *                       type: integer
 *                     fumsToken:
 *                       type: string
 *                       nullable: true
 *                     copyright:
 *                       type: string
 *                       nullable: true
 *                 - type: object
 *                   description: Concept (semantic) search result
 *                   properties:
 *                     type:
 *                       type: string
 *                       enum: [semantic]
 *                     query:
 *                       type: string
 *                     translation:
 *                       type: string
 *                     results:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           verseId:
 *                             type: string
 *                           book:
 *                             type: object
 *                           chapter:
 *                             type: integer
 *                           verse:
 *                             type: integer
 *                           verseEnd:
 *                             type: integer
 *                             nullable: true
 *                             description: Present for multi-verse range results (verse = range start), e.g. Psalm 19:1-3
 *                           title:
 *                             type: string
 *                             nullable: true
 *                             description: Present for named-passage (pericope) results, e.g. "The Parable of the Prodigal Son" — for these, text is an opening-verses snippet
 *                           summary:
 *                             type: string
 *                             nullable: true
 *                             description: 1-2 sentence passage summary (pericope results only)
 *                           text:
 *                             type: string
 *                           reference:
 *                             type: string
 *                           similarity:
 *                             type: number
 *                           sourceTranslation:
 *                             type: string
 *                             nullable: true
 *                             description: Present (as "WEB") only when this verse's text could not be resolved in the requested translation
 *                     total:
 *                       type: integer
 *                     fumsToken:
 *                       type: string
 *                       nullable: true
 *       400:
 *         description: Query parameter missing
 *       500:
 *         description: Search failed
 */
function saveSearchHistory(req: any, query: string, resultCount: number) {
  const userId = req.isAuthenticated?.() ? (req.user as any)?.id : null
  const memberId = (req.session as any)?.memberId || null
  if (userId || memberId) {
    prisma.searchHistory.create({
      data: {
        userId: userId || undefined,
        memberId: memberId || undefined,
        query: query.trim(),
        searchType: 'bible',
        resultCount,
      },
    }).catch((err: unknown) => console.error('Failed to save search history:', err))
  }
}

router.post('/smart', async (req, res) => {
  try {
    const { query, translation = 'NASB', limit = 10 } = req.body

    if (!query || typeof query !== 'string') {
      return res.status(400).json({ error: 'Query parameter is required' })
    }

    const searchType = getSearchType(query)

    if (searchType === 'direct') {
      // Direct reference (e.g. "John 3:16") — return as before
      const result = await handleDirectReference(query, translation)
      saveSearchHistory(req, query, (result as any).total ?? (result as any).verses?.length ?? 0)
      return res.json(result)
    }

    // For non-reference queries, build grouped results: books + verses
    const { getBooksForBible } = await import('../services/bible-metadata.js')
    const { resolveBibleId } = await import('../services/bible-metadata.js')

    const bibleId = await resolveBibleId(translation.toUpperCase())

    // 1. Match book names
    const bookMatches = matchBookNames(query)
    let books: { bookNumber: number; bookName: string; chapters: number; testament: string }[] = []
    if (bookMatches.length > 0 && bibleId) {
      const allBooks = await getBooksForBible(bibleId)
      books = bookMatches
        .map((match) => {
          const full = allBooks.find((b: any) => b.bookNumber === match.bookNumber)
          return full ? {
            bookNumber: full.bookNumber,
            bookName: full.bookName,
            chapters: full.chapters,
            testament: full.testament,
          } : null
        })
        .filter(Boolean) as typeof books
    }

    // 2. Concept search for verses — local pgvector embeddings, with
    //    API.Bible keyword search as fallback (model unavailable, embeddings
    //    not yet backfilled, or EMBEDDINGS_ENABLED=false)
    const { isEmbeddingsEnabled } = await import('../services/embeddings.js')
    let verseResult: any
    if (isEmbeddingsEnabled()) {
      try {
        const { searchVersesSemantic } = await import('../services/semantic-search.js')
        verseResult = await searchVersesSemantic(query, translation, limit)
        if (verseResult.results.length === 0 && !(await hasVerseEmbeddings())) {
          // Embeddings not backfilled in this environment yet
          verseResult = await handleKeywordSearch(query, translation, limit)
        }
      } catch (err) {
        console.error('Semantic search failed, falling back to API.Bible keyword search:', err)
        verseResult = await handleKeywordSearch(query, translation, limit)
      }
    } else {
      verseResult = await handleKeywordSearch(query, translation, limit)
    }
    const verses = verseResult.results || []

    const totalResults = books.length + verses.length
    saveSearchHistory(req, query, totalResults)

    return res.json({
      type: 'grouped',
      query,
      translation,
      books,
      verses,
      total: totalResults,
      fumsToken: verseResult.fumsToken,
      copyright: verseResult.copyright,
    })
  } catch (error) {
    console.error('Smart search error:', error)
    res.status(500).json({ error: 'Search failed' })
  }
})

/**
 * Handles direct Bible reference lookups via API.Bible
 */
async function handleDirectReference(query: string, translationCode: string) {
  const ref = parseReference(query)
  if (!ref) {
    return { type: 'error', query, error: 'Could not parse reference' }
  }

  const { resolveBibleId } = await import('../services/bible-metadata.js')
  const bibleId = await resolveBibleId(translationCode.toUpperCase())
  if (!bibleId) {
    return { type: 'error', query, error: `Translation '${translationCode}' not found` }
  }

  const { getBookByNumber, buildVerseId, buildPassageId } = await import('../utils/bible-id-map.js')
  const bookEntry = getBookByNumber(ref.bookNumber)

  const { getPassage, getVerse, extractFumsToken } = await import('../services/api-bible.js')
  const { parsePassageContent, parseVerseContent } = await import('../utils/bible-content-parser.js')

  try {
    if (ref.verseStart !== undefined && ref.verseEnd !== undefined) {
      // Verse range
      const passageId = buildPassageId(bookEntry.apiBibleId, ref.chapter, ref.verseStart, ref.verseEnd)
      const response = await getPassage(bibleId, passageId)
      const verses = parsePassageContent(response.data.content)
      return {
        type: 'direct', query, translation: translationCode,
        book: { bookNumber: bookEntry.bookNumber, name: bookEntry.name, abbrev: bookEntry.abbrev },
        chapter: ref.chapter,
        verses: verses.map((v) => ({
          verse: v.verse, text: v.text, reference: `${bookEntry.name} ${ref.chapter}:${v.verse}`,
        })),
        total: verses.length,
        fumsToken: extractFumsToken(response.meta),
        copyright: response.data.copyright,
      }
    } else if (ref.verseStart !== undefined) {
      // Single verse
      const verseId = buildVerseId(bookEntry.apiBibleId, ref.chapter, ref.verseStart)
      const response = await getVerse(bibleId, verseId)
      const text = parseVerseContent(response.data.content)
      return {
        type: 'direct', query, translation: translationCode,
        book: { bookNumber: bookEntry.bookNumber, name: bookEntry.name, abbrev: bookEntry.abbrev },
        chapter: ref.chapter,
        verses: [{ verse: ref.verseStart, text, reference: `${bookEntry.name} ${ref.chapter}:${ref.verseStart}` }],
        total: 1,
        fumsToken: extractFumsToken(response.meta),
        copyright: response.data.copyright,
      }
    } else {
      // Whole chapter — use chapter endpoint
      const { getChapter } = await import('../services/api-bible.js')
      const { parseChapterContent } = await import('../utils/bible-content-parser.js')
      const { buildChapterId } = await import('../utils/bible-id-map.js')
      const chapterId = buildChapterId(bookEntry.apiBibleId, ref.chapter)
      const response = await getChapter(bibleId, chapterId)
      const verses = parseChapterContent(response.data.content)
      return {
        type: 'direct', query, translation: translationCode,
        book: { bookNumber: bookEntry.bookNumber, name: bookEntry.name, abbrev: bookEntry.abbrev },
        chapter: ref.chapter,
        verses: verses.map((v) => ({
          verse: v.verse, text: v.text, reference: `${bookEntry.name} ${ref.chapter}:${v.verse}`,
        })),
        total: verses.length,
        fumsToken: extractFumsToken(response.meta),
        copyright: response.data.copyright,
      }
    }
  } catch (error: any) {
    return { type: 'error', query, error: error.message || 'Failed to fetch reference' }
  }
}

// Whether any verse embeddings exist in this environment (backfilled via
// `npm run embed:bible`). Cached once true — embeddings are never removed
// at runtime, and this avoids a count query on every search.
let verseEmbeddingsExist = false
async function hasVerseEmbeddings(): Promise<boolean> {
  if (verseEmbeddingsExist) return true
  const rows = await prisma.$queryRaw<[{ exists: boolean }]>`
    SELECT EXISTS(SELECT 1 FROM verses WHERE "embedding" IS NOT NULL) AS exists`
  verseEmbeddingsExist = rows[0]?.exists ?? false
  return verseEmbeddingsExist
}

/**
 * Handles keyword search queries via API.Bible search endpoint
 */
async function handleKeywordSearch(query: string, translationCode: string, limit: number) {
  const { resolveBibleId } = await import('../services/bible-metadata.js')
  const bibleId = await resolveBibleId(translationCode.toUpperCase())
  if (!bibleId) {
    return { type: 'semantic', query, results: [], total: 0, error: `Translation '${translationCode}' not found` }
  }

  const { searchBible, extractFumsToken } = await import('../services/api-bible.js')
  const { getBookByApiBibleId, parseVerseId } = await import('../utils/bible-id-map.js')

  const response = await searchBible(bibleId, { query, limit })
  const searchData = response.data

  const results = (searchData.verses || []).map((v) => {
    let bookNumber = 0, bookName = v.bookId, bookAbbrev = v.bookId
    try {
      const entry = getBookByApiBibleId(v.bookId)
      bookNumber = entry.bookNumber
      bookName = entry.name
      bookAbbrev = entry.abbrev
    } catch { /* use fallbacks */ }

    const parsed = parseVerseId(v.id)
    return {
      verseId: v.id,
      book: { bookNumber, name: bookName, abbrev: bookAbbrev },
      chapter: parsed.chapter,
      verse: parsed.verse,
      text: v.text,
      reference: v.reference,
      similarity: 1.0,
    }
  })

  return {
    type: 'semantic', query, translation: translationCode,
    results, total: searchData.total,
    fumsToken: extractFumsToken(response.meta),
  }
}

// ============================================
// GET SEARCH SUGGESTIONS (from static book map)
// ============================================

/**
 * @openapi
 * /api/search/suggestions:
 *   get:
 *     tags: [Search]
 *     summary: Get book name suggestions for autocomplete
 *     description: |
 *       Returns Bible book name suggestions based on a partial query string.
 *       Matches against both full book names and abbreviations from the static
 *       66-book canonical list. No API call needed — instant response.
 *     parameters:
 *       - in: query
 *         name: q
 *         required: true
 *         schema:
 *           type: string
 *           minLength: 1
 *         description: Partial book name or abbreviation
 *         example: Rom
 *     responses:
 *       200:
 *         description: List of matching book suggestions
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 suggestions:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       bookNumber:
 *                         type: integer
 *                         example: 45
 *                       bookName:
 *                         type: string
 *                         example: Romans
 *                       abbrev:
 *                         type: string
 *                         example: Rom
 *                       examples:
 *                         type: array
 *                         items:
 *                           type: string
 *                         example: ["Romans 1", "Rom 1:1"]
 */
router.get('/suggestions', async (req, res) => {
  try {
    const { q } = req.query

    if (!q || typeof q !== 'string' || q.length < 1) {
      return res.json({ suggestions: [] })
    }

    const { getAllBooks } = await import('../utils/bible-id-map.js')
    const allBooks = getAllBooks()
    const query = q.toLowerCase()

    const matches = allBooks.filter(
      (b) =>
        b.name.toLowerCase().startsWith(query) ||
        b.abbrev.toLowerCase().startsWith(query)
    )

    res.json({
      suggestions: matches.slice(0, 10).map((b) => ({
        bookNumber: b.bookNumber,
        bookName: b.name,
        abbrev: b.abbrev,
        examples: [`${b.name} 1`, `${b.abbrev} 1:1`],
      })),
    })
  } catch (error) {
    console.error('Suggestions error:', error)
    res.status(500).json({ error: 'Failed to get suggestions' })
  }
})

// ============================================
// SEARCH HISTORY
// ============================================

/**
 * @openapi
 * /api/search/recent:
 *   get:
 *     tags: [Search]
 *     summary: Get recent searches for the authenticated user
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *         description: Filter by search type (bible, media, program)
 *     responses:
 *       200:
 *         description: Recent searches
 */
router.get('/recent', async (req, res) => {
  try {
    const userId = req.isAuthenticated?.() ? (req.user as any)?.id : null
    const memberId = (req.session as any)?.memberId || null

    if (!userId && !memberId) {
      return res.json({ searches: [] })
    }

    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string) || 10))
    const searchType = req.query.type as string | undefined

    // Get recent unique searches (deduplicate by query text)
    const searches = await prisma.searchHistory.findMany({
      where: {
        ...(userId ? { userId } : { memberId }),
        ...(searchType && { searchType }),
      },
      orderBy: { createdAt: 'desc' },
      take: limit * 3, // Fetch extra to account for dedup
    })

    // Deduplicate by query (keep most recent)
    const seen = new Set<string>()
    const unique = searches.filter((s) => {
      const key = s.query.toLowerCase()
      if (seen.has(key)) return false
      seen.add(key)
      return true
    }).slice(0, limit)

    res.json({
      searches: unique.map((s) => ({
        id: s.id,
        query: s.query,
        searchType: s.searchType,
        resultCount: s.resultCount,
        createdAt: s.createdAt,
      })),
    })
  } catch (error) {
    console.error('Error fetching search history:', error)
    res.status(500).json({ error: 'Failed to fetch search history' })
  }
})

/**
 * @openapi
 * /api/search/recent:
 *   delete:
 *     tags: [Search]
 *     summary: Clear search history
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: History cleared
 */
router.delete('/recent', async (req, res) => {
  try {
    const userId = req.isAuthenticated?.() ? (req.user as any)?.id : null
    const memberId = (req.session as any)?.memberId || null

    if (!userId && !memberId) {
      return res.json({ success: true })
    }

    await prisma.searchHistory.deleteMany({
      where: userId ? { userId } : { memberId },
    })

    res.json({ success: true })
  } catch (error) {
    console.error('Error clearing search history:', error)
    res.status(500).json({ error: 'Failed to clear search history' })
  }
})

// ============================================
// MASTER SEARCH - One ranked list across types
// ============================================

/**
 * @openapi
 * /api/search/ranked:
 *   get:
 *     tags: [Search]
 *     summary: Ranked search across nine resource types
 *     description: |
 *       One list across programs, templates, members, groups, lessons, events, posts, videos and
 *       photos, scoped to the caller's organizations plus system templates. `score` is comparable
 *       only within one response's query. Foreign or malformed ids in a filter only narrow.
 *     security:
 *       - session: []
 *       - apiKey: []
 *     parameters:
 *       - in: query
 *         name: q
 *         required: true
 *         schema:
 *           type: string
 *           minLength: 2
 *           maxLength: 200
 *         description: Search query, trimmed
 *       - in: query
 *         name: types
 *         schema:
 *           type: string
 *         description: "Comma list of PROGRAM,TEMPLATE,MEMBER,GROUP,EVENT,POST,VIDEO,PHOTO"
 *       - in: query
 *         name: orgIds
 *         schema:
 *           type: string
 *         description: Comma list, at most 50; a set list also drops system templates
 *       - in: query
 *         name: groupIds
 *         schema:
 *           type: string
 *         description: Comma list, at most 50
 *       - in: query
 *         name: leaderIds
 *         schema:
 *           type: string
 *         description: Comma list of user ids, at most 50
 *       - in: query
 *         name: tags
 *         schema:
 *           type: string
 *         description: Comma list, at most 50
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *           minimum: 1
 *           maximum: 50
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *         description: The previous response's nextCursor
 *     responses:
 *       200:
 *         description: One ranked page
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 items:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       type:
 *                         type: string
 *                       id:
 *                         type: string
 *                       title:
 *                         type: string
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                       score:
 *                         type: number
 *                       imageUrl:
 *                         type: string
 *                         nullable: true
 *                       parent:
 *                         type: object
 *                         nullable: true
 *                         properties:
 *                           type:
 *                             type: string
 *                           id:
 *                             type: string
 *                           name:
 *                             type: string
 *                 nextCursor:
 *                   type: string
 *                   nullable: true
 *       400:
 *         description: Bad q, types, limit or cursor, or a filter list above 50
 *       401:
 *         description: Not authenticated
 */
router.get('/ranked', requireAuth, async (req, res) => {
  try {
    const { items, nextCursor } = await searchRanked((req.user as any).id, parseRankedParams(req.query))
    res.json({ success: true, items, nextCursor })
  } catch (error) {
    if (error instanceof SearchParamError) {
      return res.status(400).json({ success: false, error: error.message })
    }
    console.error('Ranked search error:', error)
    res.status(500).json({ success: false, error: 'Search failed' })
  }
})

// A NUL cannot be a Postgres text parameter, so it is a bad body rather than a 500.
const recentBodySchema = z
  .object({ type: z.enum(SEARCH_TYPES), id: z.string().min(1).refine((id) => !id.includes('\u0000'), 'id contains an invalid character') })
  .strict()

/**
 * @openapi
 * /api/search/recent-results:
 *   get:
 *     tags: [Search]
 *     summary: Recently opened search results
 *     description: |
 *       The caller's recently opened results, newest first, with the same filters as ranked search.
 *       Entries that were deleted, deactivated or are no longer visible to the caller are left out.
 *       `score` is always null.
 *     security:
 *       - session: []
 *       - apiKey: []
 *     parameters:
 *       - in: query
 *         name: types
 *         schema:
 *           type: string
 *         description: "Comma list of PROGRAM,TEMPLATE,MEMBER,GROUP,EVENT,POST,VIDEO,PHOTO"
 *       - in: query
 *         name: orgIds
 *         schema:
 *           type: string
 *         description: Comma list, at most 50
 *       - in: query
 *         name: groupIds
 *         schema:
 *           type: string
 *         description: Comma list, at most 50
 *       - in: query
 *         name: leaderIds
 *         schema:
 *           type: string
 *         description: Comma list of user ids, at most 50
 *       - in: query
 *         name: tags
 *         schema:
 *           type: string
 *         description: Comma list, at most 50
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *           minimum: 1
 *           maximum: 50
 *     responses:
 *       200:
 *         description: Recent results
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 items:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       type:
 *                         type: string
 *                       id:
 *                         type: string
 *                       title:
 *                         type: string
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                       score:
 *                         type: number
 *                         nullable: true
 *                       imageUrl:
 *                         type: string
 *                         nullable: true
 *                       parent:
 *                         type: object
 *                         nullable: true
 *                         properties:
 *                           type:
 *                             type: string
 *                           id:
 *                             type: string
 *                           name:
 *                             type: string
 *                       openedAt:
 *                         type: string
 *                         format: date-time
 *       400:
 *         description: Bad types or limit, or a filter list above 50
 *       401:
 *         description: Not authenticated
 */
router.get('/recent-results', requireAuth, async (req, res) => {
  try {
    const filters = parseListFilters(req.query)
    const limit = parseRecentLimit(req.query)
    res.json({ success: true, items: await listRecentResults((req.user as any).id, filters, limit) })
  } catch (error) {
    if (error instanceof SearchParamError) {
      return res.status(400).json({ success: false, error: error.message })
    }
    console.error('Recent results error:', error)
    res.status(500).json({ success: false, error: 'Failed to load recent results' })
  }
})

/**
 * @openapi
 * /api/search/recent-results:
 *   put:
 *     tags: [Search]
 *     summary: Record an opened search result
 *     description: |
 *       Adds the item to the caller's recents or moves it to the top. The caller keeps their newest
 *       100 entries. The item must be visible to the caller as the given type.
 *     security:
 *       - session: []
 *       - apiKey: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [type, id]
 *             additionalProperties: false
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [PROGRAM, TEMPLATE, MEMBER, GROUP, EVENT, POST, VIDEO, PHOTO]
 *               id:
 *                 type: string
 *     responses:
 *       200:
 *         description: Recorded
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *       400:
 *         description: Bad body
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Not found, or not visible to the caller as that type
 */
router.put('/recent-results', requireAuth, async (req, res) => {
  const body = recentBodySchema.safeParse(req.body)
  if (!body.success) {
    return res.status(400).json({ success: false, error: 'Invalid body', details: body.error.flatten() })
  }
  try {
    const recorded = await recordRecentResult((req.user as any).id, body.data.type, body.data.id)
    if (!recorded) return res.status(404).json({ success: false, error: 'Not found' })
    res.json({ success: true })
  } catch (error) {
    console.error('Record recent result error:', error)
    res.status(500).json({ success: false, error: 'Failed to record recent result' })
  }
})

/**
 * @openapi
 * /api/search/recent-results/{type}/{id}:
 *   delete:
 *     tags: [Search]
 *     summary: Remove a recent result
 *     description: Removes the caller's own entry. Answers 200 whether or not one existed.
 *     security:
 *       - session: []
 *       - apiKey: []
 *     parameters:
 *       - in: path
 *         name: type
 *         required: true
 *         schema:
 *           type: string
 *           enum: [PROGRAM, TEMPLATE, MEMBER, GROUP, EVENT, POST, VIDEO, PHOTO]
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Removed, or nothing to remove
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *       400:
 *         description: Bad type
 *       401:
 *         description: Not authenticated
 */
router.delete('/recent-results/:type/:id', requireAuth, async (req, res) => {
  const type = (SEARCH_TYPES as readonly string[]).includes(req.params.type) ? (req.params.type as (typeof SEARCH_TYPES)[number]) : null
  if (!type) return res.status(400).json({ success: false, error: `Invalid type: ${req.params.type}` })
  // A NUL cannot match a stored id (and Postgres refuses it as a parameter): answer as for an unknown id.
  if (req.params.id.includes('\u0000')) return res.json({ success: true })
  try {
    await deleteRecentResult((req.user as any).id, type, req.params.id)
    res.json({ success: true })
  } catch (error) {
    console.error('Delete recent result error:', error)
    res.status(500).json({ success: false, error: 'Failed to remove recent result' })
  }
})

/**
 * @openapi
 * /api/search/filter-options:
 *   get:
 *     tags: [Search]
 *     summary: Options for the search filter chips
 *     description: |
 *       Every organization the caller can search, with its active groups, its leaders (group creators and
 *       Owner, Admin and Group Leader role holders, one row per user) and the tags in use, merged from media
 *       and programs. Organizations, groups and leaders sort by name, then id. Tags list each category
 *       member by category and position, then the remaining tags by label. A caller with no organizations
 *       gets empty organizations, groups and leaders, and the category tags.
 *     security:
 *       - session: []
 *       - apiKey: []
 *     responses:
 *       200:
 *         description: The filter options
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 organizations:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id: { type: string }
 *                       name: { type: string }
 *                 groups:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id: { type: string }
 *                       name: { type: string }
 *                       organizationId: { type: string }
 *                 leaders:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id: { type: string }
 *                       name: { type: string }
 *                 tags:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       tag: { type: string }
 *                       label: { type: string }
 *                       category: { type: string, nullable: true }
 *       401:
 *         description: Not authenticated
 */
router.get('/filter-options', requireAuth, async (req, res) => {
  try {
    res.json({ success: true, ...(await searchFilterOptions((req.user as any).id)) })
  } catch (error) {
    console.error('Search filter options error:', error)
    res.status(500).json({ success: false, error: 'Failed to load filter options' })
  }
})

export default router
