import 'dotenv/config'
import { PrismaClient } from '../generated/prisma'
import { claudeClient, CLAUDE_MODELS } from '../services/claude.js'
import { getBookByNumber } from '../utils/bible-id-map.js'

/**
 * Index-time query generation ("doc2query") for pericope concept cards.
 *
 * For each bible_passages row, ask Claude Haiku for ~8 natural-language search
 * queries a real user might type to find that passage — concepts, situations,
 * feelings, questions, paraphrases (NOT quotes from the text). Each becomes a
 * passage_queries row pointing back at the passage; embed-bible.ts then embeds
 * the question text. At search time these embeddings give the bi-encoder a
 * pre-built bridge from how people ask to where the answer lives, so "how do I
 * stop worrying about money" matches Luke 12 even though the passage never uses
 * those words.
 *
 * Idempotent and resumable: only passages with NO existing queries are
 * processed, and inserts use skipDuplicates, so re-running continues where it
 * left off. Embeddings are filled separately by `npm run embed:bible`.
 *
 * Run per environment from a dev machine:
 *   npm run queries:generate
 *   DATABASE_URL=<prod-url> npm run queries:generate
 */

const prisma = new PrismaClient()

const QUERIES_PER_PASSAGE = 8
const CONCURRENCY = parseInt(process.env.DOC2QUERY_CONCURRENCY ?? '8', 10)

interface PassageRow {
  id: string
  bookNumber: number
  chapter: number
  verseStart: number
  verseEnd: number
  title: string
  summary: string
  themes: string[]
}

async function generateForPassage(p: PassageRow): Promise<string[]> {
  const book = getBookByNumber(p.bookNumber)
  const ref = p.verseEnd > p.verseStart
    ? `${book.name} ${p.chapter}:${p.verseStart}-${p.verseEnd}`
    : `${book.name} ${p.chapter}:${p.verseStart}`

  const message = await claudeClient.messages.create({
    model: CLAUDE_MODELS.haiku,
    max_tokens: 400,
    messages: [{
      role: 'user',
      content: `A Bible study app is indexing this passage for concept search:

Reference: ${ref}
Title: ${p.title}
Summary: ${p.summary}
Themes: ${p.themes.join(', ')}

Generate ${QUERIES_PER_PASSAGE} short, natural search queries a real person might type to find THIS passage — the way people actually search: concepts, life situations, feelings, questions, and paraphrases. Do NOT quote the passage text. Each query should target a DIFFERENT angle (emotional, theological, situational, relational, thematic) so the set covers the many ways someone might arrive here.

Return ONLY a JSON object: {"queries": ["...", "..."]}`,
    }],
  })

  const text = message.content[0].type === 'text' ? message.content[0].text : ''
  const jsonMatch = text.match(/\{[\s\S]*\}/)
  if (!jsonMatch) throw new Error('no JSON in response')
  const parsed = JSON.parse(jsonMatch[0])
  if (!Array.isArray(parsed.queries)) throw new Error('response missing queries array')
  // Dedupe + trim; cap a touch above the target in case the model over-produces.
  const seen = new Set<string>()
  const out: string[] = []
  for (const q of parsed.queries) {
    if (typeof q !== 'string') continue
    const t = q.trim()
    const key = t.toLowerCase()
    if (t.length === 0 || seen.has(key)) continue
    seen.add(key)
    out.push(t)
    if (out.length >= QUERIES_PER_PASSAGE + 2) break
  }
  return out
}

/** Run `worker` over `items` with bounded concurrency. */
async function pool<T>(items: T[], concurrency: number, worker: (item: T, index: number) => Promise<void>) {
  let cursor = 0
  const runners = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (cursor < items.length) {
      const index = cursor++
      await worker(items[index], index)
    }
  })
  await Promise.all(runners)
}

async function main() {
  try {
    // Resumable: only passages with no queries yet.
    const passages = await prisma.$queryRaw<PassageRow[]>`
      SELECT p.id, p."bookNumber", p.chapter, p."verseStart", p."verseEnd", p.title, p.summary, p.themes
      FROM bible_passages p
      WHERE NOT EXISTS (SELECT 1 FROM passage_queries q WHERE q."biblePassageId" = p.id)
      ORDER BY p.id`

    if (passages.length === 0) {
      console.log('✅ Every pericope already has generated queries — nothing to do.')
      return
    }
    console.log(`Generating ~${QUERIES_PER_PASSAGE} queries for ${passages.length} pericopes (concurrency ${CONCURRENCY})...`)

    const started = Date.now()
    let done = 0
    let failed = 0
    let inserted = 0

    await pool(passages, CONCURRENCY, async (p) => {
      try {
        const queries = await generateForPassage(p)
        if (queries.length > 0) {
          const res = await prisma.passageQuery.createMany({
            data: queries.map((text) => ({ biblePassageId: p.id, text })),
            skipDuplicates: true,
          })
          inserted += res.count
        }
      } catch (err) {
        failed++
        console.error(`  ✗ ${p.title}: ${err instanceof Error ? err.message : err}`)
      } finally {
        done++
        if (done % 100 === 0 || done === passages.length) {
          const elapsed = (Date.now() - started) / 1000
          const rate = done / elapsed
          const eta = Math.round((passages.length - done) / rate)
          console.log(`  ${done}/${passages.length} passages (${inserted} queries, ${failed} failed, ${rate.toFixed(1)}/s, ETA ${Math.floor(eta / 60)}m${eta % 60}s)`)
        }
      }
    })

    console.log(`\n🎉 doc2query generation complete: ${inserted} queries from ${passages.length - failed} passages (${failed} failed). Run "npm run embed:bible" to embed them.`)
  } catch (error) {
    console.error('\n❌ doc2query generation failed:', error)
    process.exitCode = 1
  } finally {
    await prisma.$disconnect()
  }
}

main()
