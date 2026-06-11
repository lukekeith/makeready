import 'dotenv/config'
import { PrismaClient, Prisma } from '../generated/prisma'
import { embedPassages, EMBEDDING_MODEL } from '../services/embeddings.js'

/**
 * Backfill verse embeddings for Bible concept search.
 *
 * Embeds every WEB verse with bge-small-en-v1.5 and stores the vector in
 * verses.embedding (pgvector). Idempotent and crash-resumable: only rows
 * with NULL embedding are processed, so re-running continues where it left
 * off and a completed run reports 0 remaining.
 *
 * Run per environment from a dev machine:
 *   npm run embed:bible                          (local)
 *   DATABASE_URL=<staging-url> npm run embed:bible
 *   DATABASE_URL=<prod-url> npm run embed:bible
 */

const prisma = new PrismaClient()

const TRANSLATION_CODE = 'WEB'
const BATCH_SIZE = 64

interface VerseRow {
  id: string
  text: string
}

async function embedBible() {
  try {
    const translation = await prisma.translation.findUnique({
      where: { code: TRANSLATION_CODE },
    })
    if (!translation) {
      throw new Error(`Translation ${TRANSLATION_CODE} not found — run "npm run bible:import:web" first`)
    }

    const total = await prisma.verse.count({ where: { translationId: translation.id } })
    const remaining = await prisma.$queryRaw<[{ count: bigint }]>(
      Prisma.sql`SELECT count(*) FROM verses WHERE "translationId" = ${translation.id}::uuid AND "embedding" IS NULL`
    )
    let toProcess = Number(remaining[0].count)

    console.log(`Embedding ${TRANSLATION_CODE} verses with ${EMBEDDING_MODEL}`)
    console.log(`Total: ${total}, already embedded: ${total - toProcess}, remaining: ${toProcess}\n`)

    if (toProcess === 0) {
      console.log('✅ Nothing to do — all verses embedded.')
      return
    }

    const started = Date.now()
    let processed = 0

    while (true) {
      const verses = await prisma.$queryRaw<VerseRow[]>(
        Prisma.sql`SELECT id, text FROM verses
                   WHERE "translationId" = ${translation.id}::uuid AND "embedding" IS NULL
                   ORDER BY id LIMIT ${BATCH_SIZE}`
      )
      if (verses.length === 0) break

      const vectors = await embedPassages(verses.map(v => v.text))

      const ids = verses.map(v => v.id)
      const embeddings = vectors.map(vec => `[${vec.join(',')}]`)
      await prisma.$executeRaw(
        Prisma.sql`UPDATE verses AS v SET "embedding" = u.emb::vector
                   FROM unnest(${ids}::uuid[], ${embeddings}::text[]) AS u(id, emb)
                   WHERE v.id = u.id`
      )

      processed += verses.length
      const elapsed = (Date.now() - started) / 1000
      const rate = processed / elapsed
      const eta = Math.round((toProcess - processed) / rate)
      console.log(`  embedded ${processed}/${toProcess} (${rate.toFixed(1)} verses/sec, ETA ${Math.floor(eta / 60)}m${eta % 60}s)`)
    }

    const verify = await prisma.$queryRaw<[{ count: bigint }]>(
      Prisma.sql`SELECT count(*) FROM verses WHERE "translationId" = ${translation.id}::uuid AND "embedding" IS NULL`
    )
    console.log(`\n🎉 Backfill complete: ${processed} verses embedded, ${Number(verify[0].count)} remaining`)
  } catch (error) {
    console.error('\n❌ Embedding backfill failed:', error)
    process.exitCode = 1
  } finally {
    await prisma.$disconnect()
  }
}

embedBible()
