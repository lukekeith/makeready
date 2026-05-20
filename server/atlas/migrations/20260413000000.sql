-- Update Star Wars theme typography: fontSize 18→24, lineHeight 1.9→1.4
UPDATE "text_themes"
SET
  "definition" = jsonb_set(
    jsonb_set("definition", '{typography,fontSize}',  '24',  false),
    '{typography,lineHeight}', '1.4', false
  ),
  "updatedAt" = now()
WHERE "slug" = 'star-wars' AND "isSystem" = true;
