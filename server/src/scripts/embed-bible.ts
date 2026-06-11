import 'dotenv/config'
import { PrismaClient, Prisma } from '../generated/prisma'
import { embedPassages, EMBEDDING_MODEL } from '../services/embeddings.js'

/**
 * Backfill verse and verse-window embeddings for Bible concept search.
 *
 * Two passes over the WEB translation with bge-small-en-v1.5:
 *  1. Single verses → verses.embedding (precise matches)
 *  2. 3-verse sliding windows (stride 1, within chapter) → verse_windows
 *     (concepts that span multiple verses, e.g. Psalm 19:1-3)
 *
 * Idempotent and crash-resumable: window rows are created with
 * skipDuplicates, and only rows with NULL embedding are processed, so
 * re-running continues where it left off.
 *
 * Run per environment from a dev machine:
 *   npm run embed:bible                          (local)
 *   DATABASE_URL=<staging-url> npm run embed:bible
 *   DATABASE_URL=<prod-url> npm run embed:bible
 */

const prisma = new PrismaClient()

const TRANSLATION_CODE = 'WEB'
const BATCH_SIZE = 64
const WINDOW_SIZE = 3

interface VerseRow {
  id: string
  text: string
}

/** Embed all NULL-embedding rows of a table in batches, with progress logging. */
async function embedTable(table: 'verses' | 'verse_windows', translationId: string) {
  const remaining = await prisma.$queryRaw<[{ count: bigint }]>(
    Prisma.sql`SELECT count(*) FROM ${Prisma.raw(`"${table}"`)}
               WHERE "translationId" = ${translationId}::uuid AND "embedding" IS NULL`
  )
  const toProcess = Number(remaining[0].count)
  if (toProcess === 0) {
    console.log(`✅ ${table}: nothing to embed.`)
    return
  }
  console.log(`Embedding ${toProcess} ${table} rows...`)

  const started = Date.now()
  let processed = 0

  while (true) {
    const rows = await prisma.$queryRaw<VerseRow[]>(
      Prisma.sql`SELECT id, text FROM ${Prisma.raw(`"${table}"`)}
                 WHERE "translationId" = ${translationId}::uuid AND "embedding" IS NULL
                 ORDER BY id LIMIT ${BATCH_SIZE}`
    )
    if (rows.length === 0) break

    const vectors = await embedPassages(rows.map(v => v.text))

    const ids = rows.map(v => v.id)
    const embeddings = vectors.map(vec => `[${vec.join(',')}]`)
    await prisma.$executeRaw(
      Prisma.sql`UPDATE ${Prisma.raw(`"${table}"`)} AS v SET "embedding" = u.emb::vector
                 FROM unnest(${ids}::uuid[], ${embeddings}::text[]) AS u(id, emb)
                 WHERE v.id = u.id`
    )

    processed += rows.length
    const elapsed = (Date.now() - started) / 1000
    const rate = processed / elapsed
    const eta = Math.round((toProcess - processed) / rate)
    console.log(`  ${table}: ${processed}/${toProcess} (${rate.toFixed(1)} rows/sec, ETA ${Math.floor(eta / 60)}m${eta % 60}s)`)
  }
  console.log(`✅ ${table}: ${processed} rows embedded.`)
}

/**
 * Create 3-verse sliding-window rows (text only — embedding filled by
 * embedTable). Windows never cross chapter boundaries; chapters shorter
 * than the window get a single window covering the whole chapter (skipped
 * for 1-verse chapters, which the verse-level embedding already covers).
 */
async function createWindows(translationId: string) {
  const verses = await prisma.verse.findMany({
    where: { translationId },
    select: { bookNumber: true, chapter: true, verse: true, text: true },
    orderBy: [{ bookNumber: 'asc' }, { chapter: 'asc' }, { verse: 'asc' }],
  })

  const chapters = new Map<string, { verse: number; text: string }[]>()
  for (const v of verses) {
    const key = `${v.bookNumber}:${v.chapter}`
    if (!chapters.has(key)) chapters.set(key, [])
    chapters.get(key)!.push({ verse: v.verse, text: v.text })
  }

  const windows: { translationId: string; bookNumber: number; chapter: number; verseStart: number; verseEnd: number; text: string }[] = []
  for (const [key, chapterVerses] of chapters) {
    const [bookNumber, chapter] = key.split(':').map(Number)
    if (chapterVerses.length < 2) continue
    const count = Math.max(1, chapterVerses.length - WINDOW_SIZE + 1)
    for (let i = 0; i < count; i++) {
      const slice = chapterVerses.slice(i, i + WINDOW_SIZE)
      windows.push({
        translationId,
        bookNumber,
        chapter,
        verseStart: slice[0].verse,
        verseEnd: slice[slice.length - 1].verse,
        text: slice.map(s => s.text).join(' '),
      })
    }
  }

  // Insert in chunks; unique constraint + skipDuplicates makes this idempotent
  let created = 0
  for (let i = 0; i < windows.length; i += 5000) {
    const result = await prisma.verseWindow.createMany({
      data: windows.slice(i, i + 5000),
      skipDuplicates: true,
    })
    created += result.count
  }
  console.log(`Windows: ${windows.length} total, ${created} newly created.`)
}

async function embedBible() {
  try {
    const translation = await prisma.translation.findUnique({
      where: { code: TRANSLATION_CODE },
    })
    if (!translation) {
      throw new Error(`Translation ${TRANSLATION_CODE} not found — run "npm run bible:import:web" first`)
    }

    console.log(`Embedding ${TRANSLATION_CODE} with ${EMBEDDING_MODEL}\n`)

    // Pass 1: single verses
    await embedTable('verses', translation.id)

    // Pass 2: multi-verse windows
    await createWindows(translation.id)
    await embedTable('verse_windows', translation.id)

    const verify = await prisma.$queryRaw<[{ v: bigint; w: bigint }]>(
      Prisma.sql`SELECT
        (SELECT count(*) FROM verses WHERE "translationId" = ${translation.id}::uuid AND "embedding" IS NULL) AS v,
        (SELECT count(*) FROM verse_windows WHERE "translationId" = ${translation.id}::uuid AND "embedding" IS NULL) AS w`
    )
    console.log(`\n🎉 Backfill complete. Remaining without embedding: ${Number(verify[0].v)} verses, ${Number(verify[0].w)} windows`)
  } catch (error) {
    console.error('\n❌ Embedding backfill failed:', error)
    process.exitCode = 1
  } finally {
    await prisma.$disconnect()
  }
}

embedBible()
