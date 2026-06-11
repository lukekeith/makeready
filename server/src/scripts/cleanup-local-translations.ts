import 'dotenv/config'
import { PrismaClient } from '../generated/prisma'

/**
 * Remove locally-stored Bible verses for all translations except WEB.
 *
 * WEB is the only translation needed locally: it's the embedding source for
 * semantic concept search and the local display-text source. Every other
 * translation (KJV, ASV, NET, ...) is served from API.Bible via the 14-day
 * chapter cache, so their local verse/book rows are dead weight (~31k rows
 * per translation).
 *
 * Translation rows themselves are KEPT: highlights and verse_notes FK to
 * translations with ON DELETE CASCADE, so deleting a translation row would
 * destroy user data. The rows are tiny; semantic search falls through to
 * API.Bible when a local translation has no verses.
 *
 * Idempotent. Run per environment:
 *   npx tsx src/scripts/cleanup-local-translations.ts            (local)
 *   DATABASE_URL=<env-url> npx tsx src/scripts/cleanup-local-translations.ts
 */

const prisma = new PrismaClient()

const KEEP_CODE = 'WEB'

async function cleanup() {
  try {
    const translations = await prisma.translation.findMany({
      select: {
        id: true,
        code: true,
        _count: { select: { verses: true, books: true, highlights: true, verseNotes: true } },
      },
    })

    const keep = translations.find((t) => t.code === KEEP_CODE)
    if (!keep || keep._count.verses === 0) {
      throw new Error(`${KEEP_CODE} translation missing or has no verses — aborting, nothing deleted`)
    }

    console.log('Current local translations:')
    for (const t of translations) {
      console.log(`  ${t.code}: ${t._count.verses} verses, ${t._count.books} books, ${t._count.highlights} highlights, ${t._count.verseNotes} notes`)
    }

    const remove = translations.filter((t) => t.code !== KEEP_CODE)
    if (remove.every((t) => t._count.verses === 0 && t._count.books === 0)) {
      console.log('\n✅ Nothing to do — only WEB has local verse data.')
      return
    }

    for (const t of remove) {
      if (t._count.verses === 0 && t._count.books === 0) continue
      console.log(`\nDeleting local content for ${t.code} (translation row kept — ${t._count.highlights} highlights / ${t._count.verseNotes} notes reference it)...`)
      const verses = await prisma.verse.deleteMany({ where: { translationId: t.id } })
      const books = await prisma.book.deleteMany({ where: { translationId: t.id } })
      console.log(`  ✅ ${t.code}: ${verses.count} verses, ${books.count} books deleted`)
    }

    const remaining = await prisma.verse.groupBy({ by: ['translationId'], _count: true })
    const webCount = remaining.find((r) => r.translationId === keep.id)?._count ?? 0
    console.log(`\n🎉 Cleanup complete. Remaining verse rows: ${webCount} (${KEEP_CODE} only: ${remaining.length === 1})`)
  } catch (error) {
    console.error('\n❌ Cleanup failed:', error)
    process.exitCode = 1
  } finally {
    await prisma.$disconnect()
  }
}

cleanup()
