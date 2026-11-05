/**
 * master-search D23/D40: the text each search arm matches, as SQL.
 * Every value is character-for-character the expression of the hand-managed index in
 * atlas/migrations/*_master_search_indexes.sql, so the planner can use that index.
 * test/master-search-indexes.test.ts proves the two stay equal.
 * Written over unqualified column names; use qualifySearchExpr to add a table alias.
 */
const text = (config: 'english' | 'simple', columns: string[]) =>
  `to_tsvector('${config}', ${columns.map(c => `coalesce("${c}",'')`).join(` || ' ' || `)})`

export const SEARCH_TEXT = {
  group: text('english', ['name', 'description', 'code']),
  program: text('english', ['name', 'description']),
  template: text('english', ['name', 'description']),
  lesson: text('english', ['title']),
  activity: text('english', ['title', 'readContent', 'helpTitle', 'helpDescription']),
  readBlock: text('english', ['title', 'content']),
  event: text('english', ['title', 'description', 'locationName']),
  post: text('english', ['title', 'content']),
  member: text('simple', ['firstName', 'lastName', 'email', 'phoneNumber']),
  media: text('english', ['title']),
  mediaTag: `to_tsvector('english', "tag")`,
} as const

/** The lower-case title behind each text_pattern_ops index (tiers 3 and 4). */
export const SEARCH_TITLE = {
  group: `lower("name")`,
  program: `lower("name")`,
  template: `lower("name")`,
  lesson: `lower("title")`,
  event: `lower("title")`,
  post: `lower("title")`,
  member: `lower(btrim(coalesce("firstName",'') || ' ' || coalesce("lastName",'')))`,
  media: `lower("title")`,
} as const

/** Prefixes every quoted column with a table alias: `"name"` becomes `g."name"`. */
export function qualifySearchExpr(expr: string, alias: string): string {
  return expr.replace(/"([^"]+)"/g, `${alias}."$1"`)
}
