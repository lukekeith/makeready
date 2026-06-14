import 'dotenv/config'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { PrismaClient, Prisma } from '../generated/prisma'
import { embedPassages, EMBEDDING_MODEL } from '../services/embeddings.js'

/**
 * Backfill all Bible concept-search embeddings.
 *
 * Three passes with bge-small-en-v1.5:
 *  1. Single WEB verses → verses.embedding (precise matches)
 *  2. 3-verse sliding windows (stride 1, within chapter) → verse_windows
 *     (concepts that span a few verses, e.g. Psalm 19:1-3)
 *  3. Pericope concept cards → bible_passages (narrative/thematic queries:
 *     "the prodigal son", "jealous older brother"). Rows come from the
 *     committed artifact data/pericopes-web.json (generate-pericopes.ts);
 *     the embedded text is title + summary + themes, NOT the passage text.
 *
 * Idempotent and crash-resumable: rows are created with skipDuplicates, and
 * only rows with NULL embedding are processed, so re-running continues where
 * it left off.
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

/** Embed all NULL-embedding rows of a table in batches, with progress logging.
 *  The text column embedded for bible_passages is the pre-built concept card. */
async function embedTable(table: 'verses' | 'verse_windows' | 'bible_passages' | 'passage_queries', translationId?: string) {
  const where = translationId
    ? Prisma.sql`"translationId" = ${translationId}::uuid AND "embedding" IS NULL`
    : Prisma.sql`"embedding" IS NULL`
  const textExpr = table === 'bible_passages'
    ? Prisma.raw(`title || '. ' || summary || ' Themes: ' || array_to_string(themes, ', ') AS text`)
    : Prisma.raw('text')
  const remaining = await prisma.$queryRaw<[{ count: bigint }]>(
    Prisma.sql`SELECT count(*) FROM ${Prisma.raw(`"${table}"`)} WHERE ${where}`
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
      Prisma.sql`SELECT id, ${textExpr} FROM ${Prisma.raw(`"${table}"`)}
                 WHERE ${where}
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

/**
 * Create bible_passages rows from the committed pericope artifact (text-only
 * — embedding filled by embedTable). openingText is the first 1-2 verses of
 * the range, used as the search-result snippet.
 */
async function createPassages(translationId: string) {
  const __dirname = path.dirname(fileURLToPath(import.meta.url))
  const artifactPath = path.resolve(__dirname, '../../data/pericopes-web.json')
  if (!fs.existsSync(artifactPath)) {
    console.log('⚠️  data/pericopes-web.json not found — skipping passage pass (run generate-pericopes.ts)')
    return false
  }
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8')) as Record<
    string,
    { verseStart: number; verseEnd: number; title: string; summary: string; themes: string[] }[]
  >

  const verses = await prisma.verse.findMany({
    where: { translationId },
    select: { bookNumber: true, chapter: true, verse: true, text: true },
  })
  const verseText = new Map(verses.map((v) => [`${v.bookNumber}:${v.chapter}:${v.verse}`, v.text]))

  const rows = []
  for (const [key, pericopes] of Object.entries(artifact)) {
    const [bookNumber, chapter] = key.split(':').map(Number)
    for (const p of pericopes) {
      const opening = [
        verseText.get(`${bookNumber}:${chapter}:${p.verseStart}`),
        p.verseEnd > p.verseStart ? verseText.get(`${bookNumber}:${chapter}:${p.verseStart + 1}`) : undefined,
      ].filter(Boolean).join(' ')
      rows.push({
        bookNumber,
        chapter,
        verseStart: p.verseStart,
        verseEnd: p.verseEnd,
        title: p.title,
        summary: p.summary,
        themes: p.themes,
        openingText: opening + (p.verseEnd > p.verseStart + 1 ? ' …' : ''),
      })
    }
  }

  let created = 0
  for (let i = 0; i < rows.length; i += 5000) {
    const result = await prisma.biblePassage.createMany({
      data: rows.slice(i, i + 5000),
      skipDuplicates: true,
    })
    created += result.count
  }
  console.log(`Passages: ${rows.length} in artifact, ${created} newly created.`)
  return true
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

    // Pass 3: pericope concept cards
    const hasPassages = await createPassages(translation.id)
    if (hasPassages) await embedTable('bible_passages')

    // Pass 4: doc2query — generated questions per pericope (rows created by
    // generate-passage-queries.ts; here we just embed the question text).
    await embedTable('passage_queries')

    const verify = await prisma.$queryRaw<[{ v: bigint; w: bigint; p: bigint; q: bigint }]>(
      Prisma.sql`SELECT
        (SELECT count(*) FROM verses WHERE "translationId" = ${translation.id}::uuid AND "embedding" IS NULL) AS v,
        (SELECT count(*) FROM verse_windows WHERE "translationId" = ${translation.id}::uuid AND "embedding" IS NULL) AS w,
        (SELECT count(*) FROM bible_passages WHERE "embedding" IS NULL) AS p,
        (SELECT count(*) FROM passage_queries WHERE "embedding" IS NULL) AS q`
    )
    console.log(`\n🎉 Backfill complete. Remaining without embedding: ${Number(verify[0].v)} verses, ${Number(verify[0].w)} windows, ${Number(verify[0].p)} passages, ${Number(verify[0].q)} passage-queries`)
  } catch (error) {
    console.error('\n❌ Embedding backfill failed:', error)
    process.exitCode = 1
  } finally {
    await prisma.$disconnect()
  }
}

embedBible()
