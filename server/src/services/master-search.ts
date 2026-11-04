/**
 * master-search: scope, per-type arms, scoring and the wire shape of a search item (SPEC §server).
 * One raw SQL arm per type, each carrying its own security rules and D7's filters, UNION ALLed and
 * ordered once. Every id is compared as text, because the columns are text on dev and prod and uuid on
 * a migrations-only database. Strings passed to `Prisma.raw` here are constants, never request input.
 */
import { randomUUID } from 'node:crypto'
import { Prisma, prisma } from '../lib/prisma.js'
import {
  SEARCH_TYPES,
  SearchParamError,
  buildTsQuery,
  encodeCursor,
  escapeLike,
  expandTagPicks,
  phoneDigits,
  prefixUpperBound,
  tokenizeQuery,
  type ListFilters,
  type RankedParams,
  type SearchType,
} from './master-search-query.js'
import { SEARCH_TEXT, SEARCH_TITLE, qualifySearchExpr } from './master-search-text.js'
import { memberAccessScope } from './member-access.js'
import { normalizePhone } from './member-fields.js'
import { getUserOrganizations } from './organization.js'
import { privateProgramAdminOrgIds } from './study-program.service.js'
import { listTagCategories, normalizeTag } from './tag-categories.js'

export interface SearchScope {
  userId: string
  /** The caller's orgs, narrowed by a set `orgIds` filter. */
  orgIds: string[]
  /** D8: system templates count only when no `orgIds` filter is set. */
  includeSystemTemplates: boolean
  /** D33: null for a super admin, who sees every private program in scope. */
  privateAdminOrgIds: string[] | null
  /** D30: orgs where the caller sees every member. */
  allMemberOrgIds: string[]
  /** D30: groups whose active members the caller sees in the other orgs. */
  limitedMemberGroupIds: string[]
}

/** D7's filters with an empty list already read as absent and tag picks expanded to their spellings. */
export interface ArmFilters {
  groupIds?: string[]
  leaderIds?: string[]
  tags?: string[]
}

/** A query's text match, the values every arm's tier and match predicates bind. */
export interface TextMatch {
  lowerQuery: string
  /** Exclusive end of the title prefix range; null when the range has no end. */
  prefixEnd: string | null
  tsQuery: string | null
  /** D35: `q` as a stored phone number. */
  phone: string | null
  /** D35: the LIKE pattern for a digits-only `q`. */
  phonePattern: string | null
  /** D35 (extended): the LIKE pattern for `q` as part of an email, LIKE-escaped. */
  emailPattern: string
}

export type ArmSource = TextMatch | { ids: string[] }

export interface SearchItem {
  type: SearchType
  id: string
  title: string
  createdAt: string
  score: number | null
  imageUrl: string | null
  parent: { type: string; id: string; name: string } | null
}

/** One row of an arm, before serialization. */
export interface SearchRow {
  type: SearchType
  id: string
  title: string | null
  body: string | null
  imageUrl: string | null
  parentType: string | null
  parentId: string | null
  parentName: string | null
  createdAt: Date
  createdAtText: string
  score: number | null
  scoreText: string | null
}

const raw = (sql: string) => Prisma.raw(sql)
const anyText = (values: string[]) => Prisma.sql`ANY(${values}::text[])`
const present = (list?: string[]) => (list && list.length > 0 ? list : undefined)

/** D4, D8, D30, D33, D38: what the caller may see, resolved before the query. */
export async function buildSearchScope(userId: string, orgIds?: string[]): Promise<SearchScope> {
  const orgs = await getUserOrganizations(userId)
  if (!orgs.success) throw new Error(orgs.error ?? 'Failed to fetch organizations')
  const filter = present(orgIds)
  const scoped = (orgs.data ?? []).map((o) => o.id).filter((id) => !filter || filter.includes(id))
  const [privateAdminOrgIds, access] = await Promise.all([
    privateProgramAdminOrgIds(userId),
    Promise.all(scoped.map(async (orgId) => ({ orgId, scope: await memberAccessScope(userId, orgId) }))),
  ])
  const allMemberOrgIds: string[] = []
  const limitedMemberGroupIds: string[] = []
  for (const { orgId, scope } of access) {
    if (scope.all) allMemberOrgIds.push(orgId)
    else limitedMemberGroupIds.push(...scope.groupIds)
  }
  return { userId, orgIds: scoped, includeSystemTemplates: !filter, privateAdminOrgIds, allMemberOrgIds, limitedMemberGroupIds }
}

/** Reads an empty list as absent and expands tag picks (D31). */
export async function resolveArmFilters(filters: ListFilters): Promise<ArmFilters> {
  const tags = present(filters.tags)
  return {
    groupIds: present(filters.groupIds),
    leaderIds: present(filters.leaderIds),
    tags: tags && expandTagPicks(tags, await listTagCategories()),
  }
}

/** The predicate values of a query (D1, D35, D39). */
export function buildTextMatch(q: string): TextMatch {
  const lowerQuery = q.toLowerCase()
  const digits = phoneDigits(q)
  return {
    lowerQuery,
    prefixEnd: prefixUpperBound(lowerQuery),
    tsQuery: buildTsQuery(tokenizeQuery(q)),
    phone: normalizePhone(q),
    phonePattern: digits ? `%${escapeLike(digits)}%` : null,
    emailPattern: `%${escapeLike(lowerQuery)}%`,
  }
}

/** D38: a group filter counts only active groups in scope, so a foreign id reveals nothing. */
function groupPicked(column: string, scope: SearchScope, groupIds: string[]) {
  return Prisma.sql`EXISTS (SELECT 1 FROM "groups" fg WHERE fg."id"::text = ${raw(column)}::text AND fg."isActive"
    AND fg."id"::text = ${anyText(groupIds)} AND fg."organizationId"::text = ${anyText(scope.orgIds)})`
}

function programEnrolledInPicked(programColumn: string, scope: SearchScope, groupIds: string[]) {
  return Prisma.sql`EXISTS (SELECT 1 FROM "enrollments" fe WHERE fe."studyProgramId"::text = ${raw(programColumn)}::text
    AND ${groupPicked('fe."groupId"', scope, groupIds)})`
}

function leaderIn(columns: string[], leaderIds: string[]) {
  return Prisma.sql`(${Prisma.join(columns.map((c) => Prisma.sql`${raw(c)}::text = ${anyText(leaderIds)}`), ' OR ')})`
}

function tagIn(table: string, ownerColumn: string, ownerValue: string, tags: string[]) {
  return Prisma.sql`EXISTS (SELECT 1 FROM ${raw(`"${table}"`)} ft WHERE ${raw(`ft."${ownerColumn}"`)}::text = ${raw(ownerValue)}::text
    AND lower(regexp_replace(ft."tag", '\\s+', '', 'g')) = ${anyText(tags)})`
}

/** D6, D7, D37: `undefined` means the type has no value for that filter, so a set filter drops it. */
interface FilterColumns {
  group?: (scope: SearchScope, groupIds: string[]) => Prisma.Sql
  leader?: (leaderIds: string[]) => Prisma.Sql
  tag?: (tags: string[]) => Prisma.Sql
}

function filterSql(columns: FilterColumns, scope: SearchScope, filters: ArmFilters): Prisma.Sql {
  const clause = <T>(value: T | undefined, build?: (value: T) => Prisma.Sql) => {
    if (value === undefined) return Prisma.sql`TRUE`
    return build ? build(value) : Prisma.sql`FALSE`
  }
  return Prisma.sql`${clause(filters.groupIds, columns.group && ((ids) => columns.group!(scope, ids)))}
    AND ${clause(filters.leaderIds, columns.leader)}
    AND ${clause(filters.tags, columns.tag)}`
}

/** Everything that differs between arms. All column text is constant SQL over the arm's aliases. */
interface ArmShape {
  from: string
  id: string
  createdAt: string
  /** The stored title, for tier 2: a fallback title never scores above tier 1 (D28). */
  storedTitle: string
  /** `SEARCH_TITLE[arm]`, for tiers 3 and 4. */
  lowerTitle: string
  /** `SEARCH_TEXT[arm]`, for the match and the rank. */
  vector: string
  config: 'english' | 'simple'
  outputTitle: string
  body?: string
  imageUrl?: string
  parent?: { type: 'PROGRAM' | 'GROUP'; id: string; name: string }
  visible: Prisma.Sql
  filters: FilterColumns
  /** Text other than the arm's own vector that also matches, at tier 1 (D16). */
  otherMatch?: (tsq: Prisma.Sql) => Prisma.Sql
  /**
   * A LEFT JOIN giving `ot."rank"`, the greatest rank of the row's other text and null when none of it matches.
   * Both the match and the rank read it (D39), so that text is evaluated once per query, not once per row (F4).
   */
  otherTextJoin?: (tsq: Prisma.Sql) => Prisma.Sql
  /** D35: `exact` predicates score tier 4; `loose` ones only match, at tier 1. */
  contact?: { exact: (m: TextMatch) => Prisma.Sql[]; loose: (m: TextMatch) => Prisma.Sql[] }
}

function inScope(column: string, scope: SearchScope) {
  return Prisma.sql`${raw(column)}::text = ${anyText(scope.orgIds)}`
}

/** PROGRAM's rules over alias `p`; LESSON inherits them (D33, D38). */
function programVisible(scope: SearchScope) {
  const adminOrgs = scope.privateAdminOrgIds
  const privateRule =
    adminOrgs === null
      ? Prisma.sql`TRUE`
      : Prisma.sql`(NOT p."isPrivate" OR p."creatorId"::text = ${scope.userId} OR p."leaderId"::text = ${scope.userId}
          OR p."organizationId"::text = ${anyText(adminOrgs)})`
  return Prisma.sql`p."isActive" AND ${inScope('p."organizationId"', scope)} AND ${privateRule}`
}

/** EVENT and POST rules over alias `g`, the row's group. */
function groupVisible(scope: SearchScope) {
  return Prisma.sql`g."isActive" AND ${inScope('g."organizationId"', scope)}`
}

const GROUP_PARENT = { type: 'GROUP', id: 'g."id"', name: 'g."name"' } as const

function programShape(scope: SearchScope): ArmShape {
  return {
    from: `"study_programs" p`,
    id: 'p."id"',
    createdAt: 'p."createdAt"',
    storedTitle: 'p."name"',
    lowerTitle: qualifySearchExpr(SEARCH_TITLE.program, 'p'),
    vector: qualifySearchExpr(SEARCH_TEXT.program, 'p'),
    config: 'english',
    outputTitle: 'p."name"',
    visible: programVisible(scope),
    filters: {
      group: (s, ids) => programEnrolledInPicked('p."id"', s, ids),
      leader: (ids) => leaderIn(['p."leaderId"', 'p."creatorId"'], ids),
      tag: (tags) => tagIn('study_program_tags', 'studyProgramId', 'p."id"', tags),
    },
  }
}

function lessonShape(scope: SearchScope): ArmShape {
  const activity = qualifySearchExpr(SEARCH_TEXT.activity, 'la')
  const block = qualifySearchExpr(SEARCH_TEXT.readBlock, 'rb')
  const lesson = qualifySearchExpr(SEARCH_TEXT.lesson, 'l')
  return {
    from: `"lessons" l JOIN "study_programs" p ON p."id"::text = l."studyProgramId"::text`,
    id: 'l."id"',
    createdAt: 'l."createdAt"',
    storedTitle: 'l."title"',
    lowerTitle: qualifySearchExpr(SEARCH_TITLE.lesson, 'l'),
    vector: lesson,
    config: 'english',
    outputTitle: `coalesce(nullif(btrim(l."title"), ''), 'Day ' || l."dayNumber")`,
    parent: { type: 'PROGRAM', id: 'p."id"', name: 'p."name"' },
    visible: programVisible(scope),
    filters: {
      group: (s, ids) => programEnrolledInPicked('l."studyProgramId"', s, ids),
      leader: (ids) => leaderIn(['p."leaderId"', 'p."creatorId"'], ids),
      tag: (tags) => tagIn('study_program_tags', 'studyProgramId', 'l."studyProgramId"', tags),
    },
    // `"lessonActivityId" IS NOT NULL` keeps scheduled copies out (D16) and is the partial index's predicate.
    otherTextJoin: (tsq) => Prisma.sql`LEFT JOIN (
      SELECT t."lessonId", max(t."rank") AS "rank" FROM (
        SELECT la."lessonId"::text AS "lessonId", ts_rank(${raw(activity)}, ${tsq}, 32) AS "rank"
          FROM "lesson_activities" la
          WHERE ${raw(activity)} @@ ${tsq}
        UNION ALL
        SELECT la."lessonId"::text, ts_rank(${raw(block)}, ${tsq}, 32)
          FROM "activity_read_blocks" rb JOIN "lesson_activities" la ON la."id"::text = rb."lessonActivityId"::text
          WHERE rb."lessonActivityId" IS NOT NULL AND ${raw(block)} @@ ${tsq}
      ) t GROUP BY t."lessonId"
    ) ot ON ot."lessonId" = l."id"::text`,
  }
}

function templateShape(scope: SearchScope): ArmShape {
  const system = scope.includeSystemTemplates ? Prisma.sql`t."isSystem"` : Prisma.sql`FALSE`
  return {
    from: `"lesson_templates" t`,
    id: 't."id"',
    createdAt: 't."createdAt"',
    storedTitle: 't."name"',
    lowerTitle: qualifySearchExpr(SEARCH_TITLE.template, 't'),
    vector: qualifySearchExpr(SEARCH_TEXT.template, 't'),
    config: 'english',
    outputTitle: 't."name"',
    visible: Prisma.sql`t."isActive" AND (${inScope('t."organizationId"', scope)} OR ${system})`,
    filters: { leader: (ids) => leaderIn(['t."creatorId"'], ids) },
  }
}

function groupShape(scope: SearchScope): ArmShape {
  return {
    from: `"groups" g`,
    id: 'g."id"',
    createdAt: 'g."createdAt"',
    storedTitle: 'g."name"',
    lowerTitle: qualifySearchExpr(SEARCH_TITLE.group, 'g'),
    vector: qualifySearchExpr(SEARCH_TEXT.group, 'g'),
    config: 'english',
    outputTitle: 'g."name"',
    visible: groupVisible(scope),
    filters: {
      group: (s, ids) => groupPicked('g."id"', s, ids),
      leader: (ids) => leaderIn(['g."creatorId"'], ids),
    },
  }
}

function eventShape(scope: SearchScope): ArmShape {
  return {
    from: `"events" e JOIN "groups" g ON g."id"::text = e."groupId"::text`,
    id: 'e."id"',
    createdAt: 'e."createdAt"',
    storedTitle: 'e."title"',
    lowerTitle: qualifySearchExpr(SEARCH_TITLE.event, 'e'),
    vector: qualifySearchExpr(SEARCH_TEXT.event, 'e'),
    config: 'english',
    outputTitle: 'e."title"',
    parent: GROUP_PARENT,
    visible: Prisma.sql`e."isActive" AND ${groupVisible(scope)} AND e."type"::text <> 'LESSON'
      AND NOT EXISTS (SELECT 1 FROM "events" earlier WHERE earlier."isActive"
        AND earlier."recurrenceGroupId"::text = e."recurrenceGroupId"::text
        AND (earlier."date", earlier."id"::text) < (e."date", e."id"::text))`,
    filters: {
      group: (s, ids) => groupPicked('e."groupId"', s, ids),
      leader: (ids) => leaderIn(['e."createdById"'], ids),
    },
  }
}

function postShape(scope: SearchScope): ArmShape {
  return {
    from: `"posts" po JOIN "groups" g ON g."id"::text = po."groupId"::text`,
    id: 'po."id"',
    createdAt: 'po."createdAt"',
    storedTitle: 'po."title"',
    lowerTitle: qualifySearchExpr(SEARCH_TITLE.post, 'po'),
    vector: qualifySearchExpr(SEARCH_TEXT.post, 'po'),
    config: 'english',
    outputTitle: 'po."title"',
    // Enough for serializeSearchItem's 80-character first line, without carrying a long post per row.
    body: 'left(po."content", 1000)',
    parent: GROUP_PARENT,
    visible: Prisma.sql`po."isActive" AND ${groupVisible(scope)}`,
    filters: {
      group: (s, ids) => groupPicked('po."groupId"', s, ids),
      leader: (ids) => leaderIn(['po."authorId"'], ids),
    },
  }
}

function mediaShape(type: 'photo' | 'video', scope: SearchScope): ArmShape {
  const tagVector = qualifySearchExpr(SEARCH_TEXT.mediaTag, 'mt')
  return {
    from: `"media" md`,
    id: 'md."id"',
    createdAt: 'md."createdAt"',
    storedTitle: 'md."title"',
    lowerTitle: qualifySearchExpr(SEARCH_TITLE.media, 'md'),
    vector: qualifySearchExpr(SEARCH_TEXT.media, 'md'),
    config: 'english',
    outputTitle: 'md."title"',
    imageUrl: type === 'photo' ? 'md."url"' : undefined,
    visible: Prisma.sql`md."isActive" AND ${inScope('md."organizationId"', scope)} AND md."type" = ${type}
      AND md."uploadStatus" = 'ready' AND md."source" IS DISTINCT FROM 'auto_capture'
      AND (md."groupId" IS NULL OR EXISTS (SELECT 1 FROM "groups" mg WHERE mg."id"::text = md."groupId"::text AND mg."isActive"))`,
    filters: {
      group: (s, ids) => groupPicked('md."groupId"', s, ids),
      leader: (ids) => leaderIn(['md."uploadedBy"'], ids),
      tag: (tags) => tagIn('media_tags', 'mediaId', 'md."id"', tags),
    },
    otherMatch: (tsq) => Prisma.sql`EXISTS (SELECT 1 FROM "media_tags" mt WHERE mt."mediaId"::text = md."id"::text AND ${raw(tagVector)} @@ ${tsq})`,
  }
}

function memberShape(scope: SearchScope): ArmShape {
  const name = `btrim(coalesce(m."firstName",'') || ' ' || coalesce(m."lastName",''))`
  return {
    from: `"members" m`,
    id: 'm."id"',
    createdAt: 'm."createdAt"',
    storedTitle: name,
    lowerTitle: qualifySearchExpr(SEARCH_TITLE.member, 'm'),
    vector: qualifySearchExpr(SEARCH_TEXT.member, 'm'),
    config: 'simple',
    outputTitle: `coalesce(nullif(${name}, ''), m."email", m."phoneNumber")`,
    visible: Prisma.sql`m."isActive" AND (
      EXISTS (SELECT 1 FROM "member_organizations" mo WHERE mo."memberId"::text = m."id"::text
        AND mo."organizationId"::text = ${anyText(scope.allMemberOrgIds)})
      OR EXISTS (SELECT 1 FROM "group_members" gm JOIN "groups" mg ON mg."id"::text = gm."groupId"::text
        WHERE gm."memberId"::text = m."id"::text AND gm."isActive" AND mg."isActive"
          AND mg."id"::text = ${anyText(scope.limitedMemberGroupIds)}))`,
    filters: {
      group: (s, ids) => Prisma.sql`EXISTS (SELECT 1 FROM "group_members" fgm WHERE fgm."memberId"::text = m."id"::text
        AND fgm."isActive" AND ${groupPicked('fgm."groupId"', s, ids)})`,
    },
    contact: {
      exact: (t) => [
        Prisma.sql`lower(m."email") = ${t.lowerQuery}`,
        ...(t.phone ? [Prisma.sql`m."phoneNumber" = ${t.phone}`] : []),
      ],
      // D35: `simple` keeps an address as one lexeme, so a partial address matches by substring.
      loose: (t) => [
        Prisma.sql`lower(m."email") LIKE ${t.emailPattern}`,
        ...(t.phonePattern ? [Prisma.sql`m."phoneNumber" LIKE ${t.phonePattern}`] : []),
      ],
    },
  }
}

function shapeFor(type: SearchType, scope: SearchScope): ArmShape {
  switch (type) {
    case 'PROGRAM': return programShape(scope)
    case 'LESSON': return lessonShape(scope)
    case 'TEMPLATE': return templateShape(scope)
    case 'GROUP': return groupShape(scope)
    case 'EVENT': return eventShape(scope)
    case 'POST': return postShape(scope)
    case 'PHOTO': return mediaShape('photo', scope)
    case 'VIDEO': return mediaShape('video', scope)
    case 'MEMBER': return memberShape(scope)
  }
}

/** D1, D39's tier, match and score over one arm. F14: the prefix is a range, never a LIKE. */
function textPredicates(shape: ArmShape, t: TextMatch) {
  const title = raw(shape.lowerTitle)
  const exact = Prisma.sql`${title} = ${t.lowerQuery}`
  const prefix = t.prefixEnd === null
    ? Prisma.sql`${title} ~>=~ ${t.lowerQuery}`
    : Prisma.sql`(${title} ~>=~ ${t.lowerQuery} AND ${title} ~<~ ${t.prefixEnd})`
  const tsq = t.tsQuery === null ? null : Prisma.sql`to_tsquery(${raw(`'${shape.config}'`)}, ${t.tsQuery})`
  const contactExact = shape.contact?.exact(t) ?? []
  const contactLoose = shape.contact?.loose(t) ?? []

  const tierTwo = tsq
    ? Prisma.sql`WHEN to_tsvector(${raw(`'${shape.config}'`)}, coalesce(${raw(shape.storedTitle)},'')) @@ ${tsq} THEN 2`
    : Prisma.empty
  const tier = Prisma.sql`CASE WHEN ${Prisma.join([exact, ...contactExact], ' OR ')} THEN 4
    WHEN ${prefix} THEN 3 ${tierTwo} ELSE 1 END`

  const match = Prisma.join(
    [
      exact,
      prefix,
      ...(tsq ? [Prisma.sql`${raw(shape.vector)} @@ ${tsq}`] : []),
      ...(tsq && shape.otherMatch ? [shape.otherMatch(tsq)] : []),
      ...(tsq && shape.otherTextJoin ? [Prisma.sql`ot."rank" IS NOT NULL`] : []),
      ...contactExact,
      ...contactLoose,
    ],
    ' OR ',
  )

  const join = tsq && shape.otherTextJoin ? shape.otherTextJoin(tsq) : Prisma.empty
  const ownRank = tsq && Prisma.sql`ts_rank(${raw(shape.vector)}, ${tsq}, 32)`
  const rank = !ownRank
    ? Prisma.sql`0`
    : shape.otherTextJoin
      ? Prisma.sql`coalesce(GREATEST(${ownRank}, ot."rank")::float8, 0)`
      : Prisma.sql`coalesce(${ownRank}::float8, 0)`
  return { match, join, score: Prisma.sql`(${tier})::float8 + ${rank}` }
}

/**
 * One row source for `type`: its security rules, D7's filters, and either a text match with D1's score
 * or a list of ids with a null score. Selects the columns of `SearchRow`.
 */
export function buildArm(type: SearchType, scope: SearchScope, filters: ArmFilters, source: ArmSource): Prisma.Sql {
  const shape = shapeFor(type, scope)
  const { match, join, score } =
    'ids' in source
      ? { match: Prisma.sql`${raw(shape.id)}::text = ${anyText(source.ids)}`, join: Prisma.empty, score: Prisma.sql`NULL::float8` }
      : textPredicates(shape, source)
  const column = (expr: string | undefined) => raw(expr ? `(${expr})::text` : 'NULL::text')
  return Prisma.sql`SELECT s.*, s."score"::text AS "scoreText", s."createdAt"::text AS "createdAtText" FROM (
    SELECT ${raw(`'${type}'::text`)} AS "type",
      ${column(shape.id)} AS "id",
      ${column(shape.outputTitle)} AS "title",
      ${column(shape.body)} AS "body",
      ${column(shape.imageUrl)} AS "imageUrl",
      ${raw(shape.parent ? `'${shape.parent.type}'::text` : 'NULL::text')} AS "parentType",
      ${column(shape.parent?.id)} AS "parentId",
      ${column(shape.parent?.name)} AS "parentName",
      ${raw(shape.createdAt)} AS "createdAt",
      ${score} AS "score"
    FROM ${raw(shape.from)} ${join}
    WHERE ${shape.visible}
      AND ${filterSql(shape.filters, scope, filters)}
      AND (${match})
  ) s`
}

/** D28: a post with no title shows the first line of its content, cut to 80 characters. */
function postFallbackTitle(body: string | null): string {
  const firstLine = (body ?? '').trim().split(/\r?\n/, 1)[0]
  return Array.from(firstLine).slice(0, 80).join('')
}

/** A raw arm row as the wire `SearchItem` (§Contract). */
export function serializeSearchItem(row: SearchRow): SearchItem {
  const title = row.type === 'POST' && !row.title?.trim() ? postFallbackTitle(row.body) : (row.title ?? '')
  return {
    type: row.type,
    id: row.id,
    title,
    createdAt: new Date(row.createdAt).toISOString(),
    score: row.score,
    imageUrl: row.imageUrl,
    parent: row.parentId ? { type: row.parentType as string, id: row.parentId, name: row.parentName as string } : null,
  }
}

/**
 * §Contract: a cursor the main query's casts would refuse is a 400. Postgres decides, because a shape check
 * has no way to know its range rules (`1e-999`, year 0000, an offset of +99). This query holds only those
 * casts, so a data exception (SQLSTATE class 22) can only mean the cursor; any other failure stays a failure.
 */
async function assertCursorCasts(cursor: NonNullable<RankedParams['cursor']>): Promise<void> {
  try {
    await prisma.$queryRaw`SELECT (${cursor.score}::text)::float8, (${cursor.createdAt}::text)::timestamp`
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && String(error.meta?.code).startsWith('22')) {
      throw new SearchParamError('Invalid cursor')
    }
    throw error
  }
}

/** C1: one ranked page across the requested types (D1, D2, D17, D39). */
export async function searchRanked(userId: string, params: RankedParams): Promise<{ items: SearchItem[]; nextCursor: string | null }> {
  if (params.cursor) await assertCursorCasts(params.cursor)
  const [scope, filters] = await Promise.all([buildSearchScope(userId, params.orgIds), resolveArmFilters(params)])
  const textMatch = buildTextMatch(params.q)
  const types = present(params.types) ? [...new Set(params.types)] : SEARCH_TYPES
  const arms = types.map((type) => Prisma.sql`(${buildArm(type, scope, filters, textMatch)})`)
  const cursor = params.cursor
    ? Prisma.sql`WHERE (r."score", r."createdAt", r."id") < ((${params.cursor.score}::text)::float8, (${params.cursor.createdAt}::text)::timestamp, ${params.cursor.id}::text)`
    : Prisma.empty
  const rows = await prisma.$queryRaw<SearchRow[]>(Prisma.sql`
    SELECT * FROM (${Prisma.join(arms, ' UNION ALL ')}) r
    ${cursor}
    ORDER BY r."score" DESC, r."createdAt" DESC, r."id" DESC
    LIMIT ${params.limit + 1}`)
  const page = rows.slice(0, params.limit)
  const last = page[page.length - 1]
  const nextCursor = rows.length > params.limit
    ? encodeCursor({ score: last.scoreText as string, createdAt: last.createdAtText, id: last.id })
    : null
  return { items: page.map(serializeSearchItem), nextCursor }
}

/** D12: a user keeps their newest 100 recents. */
const RECENT_KEEP = 100
const RECENT_LIST_MAX = 50

/** D11, D6, D12: the caller's recents that are still visible and pass the filters, newest first, with a null score. */
export async function listRecentResults(
  userId: string,
  filters: ListFilters,
  limit: number = RECENT_LIST_MAX,
): Promise<(SearchItem & { openedAt: string })[]> {
  // All of the user's rows (bounded by D12's cap), so a filter or a drop-out cannot starve the page.
  const recents = await prisma.$queryRaw<{ id: string; resourceType: string; resourceId: string; openedAt: Date }[]>`
    SELECT "id"::text AS "id", "resourceType", "resourceId", "openedAt" FROM "search_recent_results"
    WHERE "userId"::text = ${userId} ORDER BY "openedAt" DESC, "id" DESC`
  const wanted = present(filters.types) ? new Set<string>(filters.types) : null
  const idsByType = new Map<SearchType, string[]>()
  for (const r of recents) {
    if (!(SEARCH_TYPES as readonly string[]).includes(r.resourceType) || (wanted && !wanted.has(r.resourceType))) continue
    const type = r.resourceType as SearchType
    idsByType.set(type, [...(idsByType.get(type) ?? []), r.resourceId])
  }
  if (idsByType.size === 0) return []

  const [scope, armFilters] = await Promise.all([buildSearchScope(userId, filters.orgIds), resolveArmFilters(filters)])
  const visible = await Promise.all(
    [...idsByType].map(([type, ids]) => prisma.$queryRaw<SearchRow[]>(buildArm(type, scope, armFilters, { ids }))),
  )
  const byKey = new Map(visible.flat().map((row) => [`${row.type}:${row.id}`, row]))
  const items: (SearchItem & { openedAt: string })[] = []
  for (const r of recents) {
    const row = byKey.get(`${r.resourceType}:${r.resourceId}`)
    if (row) items.push({ ...serializeSearchItem(row), score: null, openedAt: r.openedAt.toISOString() })
    if (items.length === limit) break
  }
  return items
}

/** C3 (D10, D12): false when the caller can't see the item as `type`; else the entry moves to the top. */
export async function recordRecentResult(userId: string, type: SearchType, id: string): Promise<boolean> {
  const scope = await buildSearchScope(userId)
  const found = await prisma.$queryRaw<SearchRow[]>(Prisma.sql`${buildArm(type, scope, {}, { ids: [id] })} LIMIT 1`)
  if (found.length === 0) return false
  // The user id is bound as text and resolved through the column, so it fits both id types (D38). A database
  // built by `prisma db push` gives `id` no default (Prisma's uuid() runs in the client), so the insert supplies one,
  // converted to the column's type by json_populate_record (a text parameter is refused by a uuid column).
  await prisma.$transaction([
    prisma.$executeRaw`INSERT INTO "search_recent_results" ("id", "userId", "resourceType", "resourceId")
      VALUES ((json_populate_record(NULL::"search_recent_results", json_build_object('id', ${randomUUID()}::text)))."id", (SELECT "id" FROM "users" WHERE "id"::text = ${userId}), ${type}, ${id})
      ON CONFLICT ("userId", "resourceType", "resourceId") DO UPDATE SET "openedAt" = now()`,
    prisma.$executeRaw`DELETE FROM "search_recent_results" WHERE "id" IN (
      SELECT "id" FROM "search_recent_results" WHERE "userId"::text = ${userId}
      ORDER BY "openedAt" DESC, "id" DESC OFFSET ${RECENT_KEEP})`,
  ])
  return true
}

/** C4: removes only the caller's entry; none existing is not an error. */
export async function deleteRecentResult(userId: string, type: SearchType, id: string): Promise<void> {
  await prisma.$executeRaw`DELETE FROM "search_recent_results"
    WHERE "userId"::text = ${userId} AND "resourceType" = ${type} AND "resourceId" = ${id}`
}

export interface FilterOptions {
  organizations: { id: string; name: string }[]
  groups: { id: string; name: string; organizationId: string }[]
  leaders: { id: string; name: string }[]
  tags: { tag: string; label: string; category: string | null }[]
}

/** Code-point order, so a sort never depends on the database's collation (D38). */
const compareText = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0)
const byNameThenId = <T extends { id: string; name: string }>(a: T, b: T) => compareText(a.name, b.name) || compareText(a.id, b.id)
const titleCase = (s: string) => s.replace(/(^|\s)(\S)/g, (_m, space: string, c: string) => space + c.toUpperCase())

/** D31: category members first (categories, then members, by position), then the other stored tags by label. */
async function buildTagOptions(orgIds: string[]): Promise<FilterOptions['tags']> {
  const [categories, mediaTags, programTags] = await Promise.all([
    listTagCategories(),
    orgIds.length
      ? prisma.mediaTag.findMany({ where: { media: { isActive: true, organizationId: { in: orgIds } } }, select: { tag: true }, distinct: ['tag'] })
      : [],
    orgIds.length
      ? prisma.studyProgramTag.findMany({ where: { studyProgram: { isActive: true, organizationId: { in: orgIds } } }, select: { tag: true }, distinct: ['tag'] })
      : [],
  ])
  const options: FilterOptions['tags'] = []
  const known = new Set<string>()
  for (const category of categories) {
    const seenPositions = new Set<number>()
    for (const member of category.tags) {
      known.add(normalizeTag(member.tag))
      if (seenPositions.has(member.position)) continue
      seenPositions.add(member.position)
      options.push({ tag: member.tag, label: member.label, category: category.name })
    }
  }
  // The first stored spelling of each remaining normalized tag, in code-point order so the choice is stable.
  const firstSpelling = new Map<string, string>()
  for (const { tag } of [...mediaTags, ...programTags].sort((a, b) => compareText(a.tag, b.tag))) {
    const key = normalizeTag(tag)
    if (key && !known.has(key) && !firstSpelling.has(key)) firstSpelling.set(key, tag)
  }
  const rest = [...firstSpelling.values()].map((tag) => ({ tag, label: titleCase(tag.trim()), category: null }))
  rest.sort((a, b) => compareText(a.label, b.label) || compareText(a.tag, b.tag))
  return [...options, ...rest]
}

/** C5 (D13, D14, D31, D38): the options of the filter chips, across the caller's orgs. */
export async function searchFilterOptions(userId: string): Promise<FilterOptions> {
  const orgs = await getUserOrganizations(userId)
  if (!orgs.success) throw new Error(orgs.error ?? 'Failed to fetch organizations')
  const organizations = (orgs.data ?? []).map((o) => ({ id: o.id, name: o.name })).sort(byNameThenId)
  const orgIds = organizations.map((o) => o.id)

  // The definition of routes/programs.ts's /group-leaders, across orgs and without counts.
  const [groups, creators, roleHolders, tags] = orgIds.length
    ? await Promise.all([
        prisma.group.findMany({ where: { organizationId: { in: orgIds }, isActive: true }, select: { id: true, name: true, organizationId: true } }),
        prisma.group.findMany({
          where: { organizationId: { in: orgIds }, isActive: true },
          select: { creator: { select: { id: true, name: true } } },
          distinct: ['creatorId'],
        }),
        prisma.userRole.findMany({
          where: { organizationId: { in: orgIds }, role: { name: { in: ['Owner', 'Admin', 'Group Leader'] } } },
          select: { user: { select: { id: true, name: true } } },
        }),
        buildTagOptions(orgIds),
      ])
    : [[], [], [], await buildTagOptions([])]

  const leadersById = new Map<string, { id: string; name: string }>()
  for (const user of [...creators.map((c) => c.creator), ...roleHolders.map((r) => r.user)]) {
    if (user) leadersById.set(user.id, { id: user.id, name: user.name })
  }
  return {
    organizations,
    groups: [...groups].sort(byNameThenId),
    leaders: [...leadersById.values()].sort(byNameThenId),
    tags,
  }
}
