-- Create "tag_categories" table
CREATE TABLE "tag_categories" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "key" character varying NOT NULL, "name" character varying NOT NULL, "position" integer NOT NULL, "createdAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "tag_categories_key_key" UNIQUE ("key"));
-- Set comment to column: "key" on table: "tag_categories"
COMMENT ON COLUMN "tag_categories"."key" IS 'Stable key, e.g. bible-books';
-- Set comment to column: "name" on table: "tag_categories"
COMMENT ON COLUMN "tag_categories"."name" IS 'Section header, e.g. Books of the Bible';
-- Set comment to column: "position" on table: "tag_categories"
COMMENT ON COLUMN "tag_categories"."position" IS 'Section order, ascending';
-- Create "tag_category_tags" table
CREATE TABLE "tag_category_tags" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "categoryId" uuid NOT NULL, "tag" character varying NOT NULL, "label" character varying NOT NULL, "position" integer NOT NULL, "createdAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "tag_category_tags_tag_key" UNIQUE ("tag"), CONSTRAINT "fk_tag_category_tags_category" FOREIGN KEY ("categoryId") REFERENCES "tag_categories" ("id") ON UPDATE NO ACTION ON DELETE CASCADE);
-- Create index "idx_tag_category_tags_categoryId_position" to table: "tag_category_tags"
CREATE INDEX "idx_tag_category_tags_categoryId_position" ON "tag_category_tags" ("categoryId", "position");
-- Set comment to column: "tag" on table: "tag_category_tags"
COMMENT ON COLUMN "tag_category_tags"."tag" IS 'Normalized spelling: lowercase, all whitespace removed';
-- Set comment to column: "label" on table: "tag_category_tags"
COMMENT ON COLUMN "tag_category_tags"."label" IS 'Display label, e.g. 1 Samuel';
-- Set comment to column: "position" on table: "tag_category_tags"
COMMENT ON COLUMN "tag_category_tags"."position" IS 'Order inside the category; the spellings of one member share it';
-- tag-categories D4/D11: Books of the Bible, MakeReady-defined — the 66 full book names (BOOK_MAP keys equal to
-- the name lowercased with whitespace removed) plus three spelled-out variants; never an abbreviation.
INSERT INTO "tag_categories" ("id", "key", "name", "position") VALUES (gen_random_uuid(), 'bible-books', 'Books of the Bible', 1) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'genesis', 'Genesis', 1) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'exodus', 'Exodus', 2) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'leviticus', 'Leviticus', 3) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'numbers', 'Numbers', 4) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'deuteronomy', 'Deuteronomy', 5) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'joshua', 'Joshua', 6) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'judges', 'Judges', 7) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'ruth', 'Ruth', 8) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '1samuel', '1 Samuel', 9) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '2samuel', '2 Samuel', 10) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '1kings', '1 Kings', 11) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '2kings', '2 Kings', 12) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '1chronicles', '1 Chronicles', 13) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '2chronicles', '2 Chronicles', 14) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'ezra', 'Ezra', 15) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'nehemiah', 'Nehemiah', 16) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'esther', 'Esther', 17) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'job', 'Job', 18) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'psalm', 'Psalms', 19) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'psalms', 'Psalms', 19) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'proverbs', 'Proverbs', 20) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'ecclesiastes', 'Ecclesiastes', 21) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'songofsolomon', 'Song of Solomon', 22) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'songofsongs', 'Song of Solomon', 22) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'isaiah', 'Isaiah', 23) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'jeremiah', 'Jeremiah', 24) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'lamentations', 'Lamentations', 25) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'ezekiel', 'Ezekiel', 26) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'daniel', 'Daniel', 27) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'hosea', 'Hosea', 28) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'joel', 'Joel', 29) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'amos', 'Amos', 30) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'obadiah', 'Obadiah', 31) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'jonah', 'Jonah', 32) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'micah', 'Micah', 33) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'nahum', 'Nahum', 34) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'habakkuk', 'Habakkuk', 35) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'zephaniah', 'Zephaniah', 36) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'haggai', 'Haggai', 37) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'zechariah', 'Zechariah', 38) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'malachi', 'Malachi', 39) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'matthew', 'Matthew', 40) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'mark', 'Mark', 41) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'luke', 'Luke', 42) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'john', 'John', 43) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'acts', 'Acts', 44) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'romans', 'Romans', 45) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '1corinthians', '1 Corinthians', 46) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '2corinthians', '2 Corinthians', 47) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'galatians', 'Galatians', 48) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'ephesians', 'Ephesians', 49) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'philippians', 'Philippians', 50) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'colossians', 'Colossians', 51) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '1thessalonians', '1 Thessalonians', 52) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '2thessalonians', '2 Thessalonians', 53) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '1timothy', '1 Timothy', 54) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '2timothy', '2 Timothy', 55) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'titus', 'Titus', 56) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'philemon', 'Philemon', 57) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'hebrews', 'Hebrews', 58) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'james', 'James', 59) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '1peter', '1 Peter', 60) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '2peter', '2 Peter', 61) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '1john', '1 John', 62) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '2john', '2 John', 63) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), '3john', '3 John', 64) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'jude', 'Jude', 65) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'revelation', 'Revelation', 66) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'revelations', 'Revelation', 66) ON CONFLICT DO NOTHING;
