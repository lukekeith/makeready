---
description: Import Bible data (KJV) into the database
---

You are importing Bible data into the MakeReady database. This will populate the database with the King James Version (KJV) translation including all 66 books and ~31,000 verses.

## Your Task

### Step 1: Check Database Status

First, verify the database is ready:

```bash
npx prisma db push
```

This ensures the Bible schema is properly migrated.

### Step 2: Run the Import Script

Execute the Bible import script:

```bash
npx tsx src/scripts/import-bible.ts
```

### Step 3: Monitor Progress

The import script will:
- Create the KJV translation record
- Create all 66 books (Genesis through Revelation)
- Import verses chapter by chapter
- Display progress: "Chapter X: Y verses (Total: Z)"

**Expected behavior:**
- Takes approximately 2 hours with rate limiting (100ms between requests)
- Imports ~31,000 verses total
- Shows real-time progress for each chapter

### Step 4: Handle Issues

If the script encounters errors:

**Connection errors:**
- Check that `DATABASE_URL` is set in `.env`
- Verify database is accessible
- Try: `npx prisma db push` to test connection

**API rate limiting:**
- The script has built-in 100ms delays
- If you see 429 errors, the delay may need to be increased
- Consider running during off-peak hours

**Partial imports:**
- Script skips duplicates automatically
- Safe to re-run if interrupted
- Check progress: `SELECT COUNT(*) FROM verses;`

### Step 5: Verify Import

After completion, verify the data:

```bash
# Count verses imported
echo "SELECT COUNT(*) as verse_count FROM verses;" | npx prisma db execute --stdin

# Check translations exist
curl http://localhost:3001/api/bible/translations

# Test reading a chapter
curl http://localhost:3001/api/bible/KJV/1/1

# Test search
curl "http://localhost:3001/api/bible/search?query=God&limit=5"
```

### Step 6: Report Results

Provide a summary to the user:

```
✅ Import Complete!

Translation: King James Version (KJV)
Books: 66
Verses: ~31,000
Duration: ~X hours

Next steps:
- Test the API endpoints
- Add full-text search index (optional)
- Import additional translations (ESV, NIV, etc.)
```

## Expected Output Format

During import, you should see output like:

```
Starting Bible import...
Creating KJV translation...
✅ Translation created: King James Version

Creating books...
  ✅ Created book: Genesis
  ✅ Created book: Exodus
  ...

Importing verses (this will take a while)...

Importing Genesis...
  ✅ Chapter 1: 31 verses (Total: 31)
  ✅ Chapter 2: 25 verses (Total: 56)
  ...

Importing Exodus...
  ✅ Chapter 1: 22 verses (Total: 1569)
  ...

🎉 Bible import completed successfully!
   Total verses imported: 31102
   Translation: King James Version (KJV)
```

## Troubleshooting

### Error: "Can't reach database server"
**Solution:** Check `.env` file has correct `DATABASE_URL`

### Error: "Failed to fetch [Book] [Chapter]"
**Solution:** API rate limiting - script will skip and continue. Can re-run to fill gaps.

### Error: "Unique constraint failed"
**Solution:** Data already exists. This is safe - script skips duplicates.

### Import is too slow
**Options:**
1. Let it run overnight (~2 hours total)
2. Use a bulk data source instead (bible_databases repo)
3. Increase batch size in the script

## Alternative: Fast Import (Advanced)

If you have a JSON file with Bible data, you can modify the import script:

```typescript
// Instead of fetching from API, load from file
const data = JSON.parse(fs.readFileSync('kjv.json', 'utf-8'))

// Batch insert all verses at once
await prisma.verse.createMany({
  data: data.verses,
  skipDuplicates: true
})
```

This reduces import time from 2 hours to ~5 minutes.

## Important Notes

- **Do not interrupt** the script if possible (creates partial data)
- **Safe to re-run** - uses `skipDuplicates: true`
- **Rate limited** - respects API limits (100ms delay between requests)
- **Progress is saved** - each successful chapter is committed to DB
- **No rollback** - if interrupted, already-imported data remains

## Success Criteria

- ✅ KJV translation created
- ✅ 66 books created
- ✅ ~31,000 verses imported
- ✅ API endpoints return data
- ✅ Search works (even without full-text index)

After successful import, the Bible API is fully functional!
