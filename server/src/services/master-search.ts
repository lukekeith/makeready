/**
 * master-search: scope, per-type arms, scoring and the wire shape of a search item (SPEC §server).
 * One raw SQL arm per type, each carrying its own security rules and D7's filters, UNION ALLed and
 * ordered once. Every id is compared as text, because the columns are text on dev and prod and uuid on
 * a migrations-only database. Strings passed to `Prisma.raw` here are constants, never request input.
 */
import { Prisma, prisma } from '../lib/prisma.js'
import {
  SEARCH_TYPES,
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
import { listTagCategories } from './tag-categories.js'

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
  /** A LATERAL giving `lr."rank"`, used in place of the vector's own rank (D39). */
  rankLateral?: (tsq: Prisma.Sql) => Prisma.Sql
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
  // `"lessonActivityId" IS NOT NULL` keeps scheduled copies out (D16) and is the partial index's predicate.
  const blockFrom = raw(`"activity_read_blocks" rb JOIN "lesson_activities" la ON la."id"::text = rb."lessonActivityId"::text
    WHERE rb."lessonActivityId" IS NOT NULL AND la."lessonId"::text = l."id"::text`)
  const activityFrom = raw(`"lesson_activities" la WHERE la."lessonId"::text = l."id"::text`)
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
    otherMatch: (tsq) => Prisma.sql`EXISTS (SELECT 1 FROM ${activityFrom} AND ${raw(activity)} @@ ${tsq})
      OR EXISTS (SELECT 1 FROM ${blockFrom} AND ${raw(block)} @@ ${tsq})`,
    rankLateral: (tsq) => Prisma.sql`CROSS JOIN LATERAL (SELECT GREATEST(
      ts_rank(${raw(lesson)}, ${tsq}, 32),
      (SELECT max(ts_rank(${raw(activity)}, ${tsq}, 32)) FROM ${activityFrom} AND ${raw(activity)} @@ ${tsq}),
      (SELECT max(ts_rank(${raw(block)}, ${tsq}, 32)) FROM ${blockFrom} AND ${raw(block)} @@ ${tsq})
    ) AS "rank") lr`,
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
      loose: (t) => (t.phonePattern ? [Prisma.sql`m."phoneNumber" LIKE ${t.phonePattern}`] : []),
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
      ...contactExact,
      ...contactLoose,
    ],
    ' OR ',
  )

  const lateral = tsq && shape.rankLateral ? shape.rankLateral(tsq) : Prisma.empty
  const rank = !tsq
    ? Prisma.sql`0`
    : shape.rankLateral
      ? Prisma.sql`coalesce(lr."rank"::float8, 0)`
      : Prisma.sql`coalesce(ts_rank(${raw(shape.vector)}, ${tsq}, 32)::float8, 0)`
  return { match, lateral, score: Prisma.sql`(${tier})::float8 + ${rank}` }
}

/**
 * One row source for `type`: its security rules, D7's filters, and either a text match with D1's score
 * or a list of ids with a null score. Selects the columns of `SearchRow`.
 */
export function buildArm(type: SearchType, scope: SearchScope, filters: ArmFilters, source: ArmSource): Prisma.Sql {
  const shape = shapeFor(type, scope)
  const { match, lateral, score } =
    'ids' in source
      ? { match: Prisma.sql`${raw(shape.id)}::text = ${anyText(source.ids)}`, lateral: Prisma.empty, score: Prisma.sql`NULL::float8` }
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
    FROM ${raw(shape.from)} ${lateral}
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

/** C1: one ranked page across the requested types (D1, D2, D17, D39). */
export async function searchRanked(userId: string, params: RankedParams): Promise<{ items: SearchItem[]; nextCursor: string | null }> {
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
