/**
 * master-search D23/D40: the text each search arm matches, as SQL.
 * Every value is character-for-character the expression of the hand-managed index in
 * atlas/migrations/*_master_search_indexes.sql (the lesson arms: *_text_activity_search_indexes.sql), so the
 * planner can use that index. test/master-search-indexes.test.ts and test/master-search-lessons.test.ts prove
 * the two stay equal.
 * Written over unqualified column names; use qualifySearchExpr to add a table alias.
 */
const text = (config: 'english' | 'simple', columns: string[]) =>
  `to_tsvector('${config}', ${columns.map(c => `coalesce("${c}",'')`).join(` || ' ' || `)})`

/**
 * The text of an activity's document (02 §3, §8): every canvas object's `text` plus a `write`/`poll` page's prompt.
 * `jsonb_path_query_array` is immutable, so it can sit in a GIN index; lax mode reads a missing path as no text.
 */
export const LESSON_SEARCH_TEXT_SQL =
  `to_tsvector('english', jsonb_path_query_array("document", '$.content.objects[*].text') || jsonb_path_query_array("document", '$.content.prompt.text'))`

export const SEARCH_TEXT = {
  group: text('english', ['name', 'description', 'code']),
  program: text('english', ['name', 'description']),
  template: text('english', ['name', 'description']),
  /** A lesson's title lives on its versions (`lesson_versions`). */
  lesson: text('english', ['title']),
  /** A lesson's activity text is in its documents (`content_activities`). */
  activity: LESSON_SEARCH_TEXT_SQL,
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
  event: `lower("title")`,
  post: `lower("title")`,
  member: `lower(btrim(coalesce("firstName",'') || ' ' || coalesce("lastName",'')))`,
  media: `lower("title")`,
} as const

/** Prefixes every quoted column with a table alias: `"name"` becomes `g."name"`. */
export function qualifySearchExpr(expr: string, alias: string): string {
  return expr.replace(/"([^"]+)"/g, `${alias}."$1"`)
}
