import 'dotenv/config'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { PrismaClient } from '../generated/prisma'
import { claudeClient, CLAUDE_MODELS } from '../services/claude.js'

/**
 * Generate Bible pericopes (natural passage units) with concept cards.
 *
 * For each of the 1,189 chapters, Claude Haiku segments the WEB text into
 * pericopes and writes a title, 1-2 sentence summary, and theme keywords for
 * each. These "concept cards" are what semantic search embeds for
 * narrative/thematic queries — raw passage text never matches queries like
 * "the prodigal son" (the word "prodigal" appears nowhere in Luke 15), but
 * a card titled "The Parable of the Prodigal Son" with themes
 * [repentance, fatherly love, jealousy] does.
 *
 * Output: server/data/pericopes-web.json — a COMMITTED artifact. Claude
 * output is non-deterministic, so we generate once, review, commit, and every
 * environment imports identical data (embed-bible.ts pass 3). Regeneration is
 * a deliberate act, not a side effect of deployment.
 *
 * Resumable: chapters already present in the output file are skipped, so the
 * script can be re-run after rate limits or failures. One-time cost ~$4.
 *
 * Usage: npx tsx src/scripts/generate-pericopes.ts [--book N] [--limit N]
 */

const prisma = new PrismaClient()

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const OUTPUT_PATH = path.resolve(__dirname, '../../data/pericopes-web.json')
const CONCURRENCY = 5
const MAX_ATTEMPTS = 3

interface Pericope {
  verseStart: number
  verseEnd: number
  title: string
  summary: string
  themes: string[]
}

/** Output file shape: { "<bookNumber>:<chapter>": Pericope[] } */
type PericopeFile = Record<string, Pericope[]>

function loadExisting(): PericopeFile {
  try {
    return JSON.parse(fs.readFileSync(OUTPUT_PATH, 'utf8')) as PericopeFile
  } catch {
    return {}
  }
}

function save(data: PericopeFile) {
  fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true })
  // Stable key order so regeneration diffs are reviewable
  const sorted = Object.fromEntries(
    Object.entries(data).sort(([a], [b]) => {
      const [ab, ac] = a.split(':').map(Number)
      const [bb, bc] = b.split(':').map(Number)
      return ab - bb || ac - bc
    })
  )
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(sorted, null, 1))
}

function buildPrompt(bookName: string, chapter: number, verses: { verse: number; text: string }[]): string {
  const text = verses.map((v) => `${v.verse}. ${v.text}`).join('\n')
  return `Segment this Bible chapter into its natural passage units (pericopes) — complete narrative episodes, parables, discourses, psalms/poems, or argument units as a study Bible would divide them.

For each pericope provide:
- "verseStart" and "verseEnd" (the unit's verse range)
- "title": the conventional name if one exists (e.g. "The Parable of the Prodigal Son", "David and Goliath"), otherwise a clear descriptive title
- "summary": 1-2 sentences capturing what happens and what it means
- "themes": 3-6 lowercase keywords/phrases people might search for (concepts, emotions, doctrines — e.g. "forgiveness", "overcoming fear", "God's faithfulness")

Rules:
- Cover EVERY verse from 1 to ${verses[verses.length - 1].verse} exactly once — contiguous, no gaps, no overlaps
- Most chapters have 2-6 pericopes; never split below 3 verses unless the chapter is very short
- Respond with ONLY a JSON array, no markdown fences, no commentary

${bookName} chapter ${chapter}:
${text}`
}

function validate(pericopes: Pericope[], maxVerse: number): string | null {
  if (!Array.isArray(pericopes) || pericopes.length === 0) return 'not a non-empty array'
  let expected = 1
  for (const p of pericopes) {
    if (
      typeof p.verseStart !== 'number' || typeof p.verseEnd !== 'number' ||
      typeof p.title !== 'string' || !p.title.trim() ||
      typeof p.summary !== 'string' || !p.summary.trim() ||
      !Array.isArray(p.themes) || p.themes.length === 0
    ) return `malformed pericope: ${JSON.stringify(p).slice(0, 120)}`
    if (p.verseStart !== expected) return `coverage gap: expected verse ${expected}, got ${p.verseStart}`
    if (p.verseEnd < p.verseStart || p.verseEnd > maxVerse) return `bad range ${p.verseStart}-${p.verseEnd}`
    expected = p.verseEnd + 1
  }
  if (expected !== maxVerse + 1) return `coverage ends at ${expected - 1}, chapter has ${maxVerse}`
  return null
}

function parseResponse(raw: string): Pericope[] {
  // Strip accidental markdown fences
  const cleaned = raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '')
  return JSON.parse(cleaned) as Pericope[]
}

async function generateChapter(
  bookName: string,
  chapter: number,
  verses: { verse: number; text: string }[]
): Promise<Pericope[]> {
  const maxVerse = verses[verses.length - 1].verse
  let lastError = ''

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const feedback = lastError
      ? `\n\nYour previous attempt was invalid: ${lastError}. Fix this and output the corrected JSON array.`
      : ''
    const response = await claudeClient.messages.create({
      model: CLAUDE_MODELS.haiku,
      max_tokens: 4000,
      messages: [{ role: 'user', content: buildPrompt(bookName, chapter, verses) + feedback }],
    })
    const text = response.content.find((b) => b.type === 'text')?.text ?? ''
    try {
      const pericopes = parseResponse(text)
      const error = validate(pericopes, maxVerse)
      if (!error) return pericopes
      lastError = error
    } catch (err) {
      lastError = `invalid JSON: ${(err as Error).message}`
    }
  }
  throw new Error(`failed after ${MAX_ATTEMPTS} attempts: ${lastError}`)
}

async function main() {
  const bookFilter = process.argv.includes('--book')
    ? parseInt(process.argv[process.argv.indexOf('--book') + 1], 10)
    : null
  const limit = process.argv.includes('--limit')
    ? parseInt(process.argv[process.argv.indexOf('--limit') + 1], 10)
    : null

  const web = await prisma.translation.findUnique({ where: { code: 'WEB' } })
  if (!web) throw new Error('WEB translation not found')

  const books = await prisma.book.findMany({
    where: { translationId: web.id, ...(bookFilter ? { bookNumber: bookFilter } : {}) },
    orderBy: { bookNumber: 'asc' },
    select: { bookNumber: true, bookName: true },
  })
  const bookNames = new Map(books.map((b) => [b.bookNumber, b.bookName]))

  const verses = await prisma.verse.findMany({
    where: { translationId: web.id, ...(bookFilter ? { bookNumber: bookFilter } : {}) },
    orderBy: [{ bookNumber: 'asc' }, { chapter: 'asc' }, { verse: 'asc' }],
    select: { bookNumber: true, chapter: true, verse: true, text: true },
  })

  const chapters = new Map<string, { verse: number; text: string }[]>()
  for (const v of verses) {
    const key = `${v.bookNumber}:${v.chapter}`
    if (!chapters.has(key)) chapters.set(key, [])
    chapters.get(key)!.push({ verse: v.verse, text: v.text })
  }

  const existing = loadExisting()
  let pending = [...chapters.keys()].filter((key) => !existing[key])
  if (limit) pending = pending.slice(0, limit)

  console.log(`Chapters: ${chapters.size} total, ${chapters.size - pending.length} already generated, ${pending.length} to do`)
  if (pending.length === 0) {
    console.log('✅ Nothing to do.')
    return
  }

  const started = Date.now()
  let done = 0
  let failed = 0

  // Simple worker pool
  const queue = [...pending]
  await Promise.all(
    Array.from({ length: CONCURRENCY }, async () => {
      while (queue.length > 0) {
        const key = queue.shift()!
        const [bookNumber, chapter] = key.split(':').map(Number)
        const bookName = bookNames.get(bookNumber) ?? `Book ${bookNumber}`
        try {
          const pericopes = await generateChapter(bookName, chapter, chapters.get(key)!)
          existing[key] = pericopes
          save(existing)
          done++
          if (done % 20 === 0 || queue.length === 0) {
            const rate = done / ((Date.now() - started) / 1000)
            const eta = Math.round(queue.length / rate)
            console.log(`  ${done}/${pending.length} chapters (${failed} failed, ETA ${Math.floor(eta / 60)}m${eta % 60}s) — ${bookName} ${chapter}: ${pericopes.length} pericopes`)
          }
        } catch (err) {
          failed++
          console.error(`  ⚠️  ${bookName} ${chapter}: ${(err as Error).message}`)
        }
      }
    })
  )

  console.log(`\n🎉 Generation complete: ${done} chapters written, ${failed} failed (re-run to retry failures)`)
  const total = Object.values(existing).reduce((s, p) => s + p.length, 0)
  console.log(`   Total pericopes in artifact: ${total}`)
}

main()
  .catch((err) => {
    console.error('Generation failed:', err)
    process.exitCode = 1
  })
  .finally(() => prisma.$disconnect())
