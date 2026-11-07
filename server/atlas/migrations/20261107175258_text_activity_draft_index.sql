-- text-activity D31/SC13: hand-managed. atlas.hcl's drop_index skip keeps these out of migrate diff.
-- enrollmentId is NULL for program versions; NULLS NOT DISTINCT makes NULL collide with NULL.
CREATE UNIQUE INDEX "lesson_versions_one_draft_key"
  ON "lesson_versions" ("lessonId", "enrollmentId") NULLS NOT DISTINCT
  WHERE "status" = 'DRAFT';
CREATE UNIQUE INDEX "lesson_versions_number_key"
  ON "lesson_versions" ("lessonId", "enrollmentId", "number") NULLS NOT DISTINCT;
