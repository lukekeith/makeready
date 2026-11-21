/**
 * Backfill script: derive StudyNote.title / preview from content for every
 * existing row (D11). Idempotent: only rows whose derived values differ are
 * written, and the write is raw SQL so @updatedAt is left untouched.
 *
 * Local:        npm run backfill:note-titles [-- --dry-run]
 * Staging/prod: node dist/scripts/backfill-note-titles.js [--dry-run]
 */

import { fileURLToPath } from 'node:url'
import { prisma } from '../lib/prisma.js'
import { deriveTitlePreview } from '../services/note-title.js'

export async function backfillNoteTitles(
  opts: { dryRun?: boolean; batchSize?: number } = {},
): Promise<{ scanned: number; updated: number }> {
  const { dryRun = false, batchSize = 500 } = opts
  let scanned = 0
  let updated = 0
  let lastId: string | undefined

  for (;;) {
    const rows = await prisma.studyNote.findMany({
      where: lastId ? { id: { gt: lastId } } : undefined,
      orderBy: { id: 'asc' },
      take: batchSize,
      select: { id: true, content: true, title: true, preview: true },
    })
    if (rows.length === 0) break

    for (const row of rows) {
      scanned++
      const derived = deriveTitlePreview(row.content)
      if (derived.title === row.title && derived.preview === row.preview) continue
      updated++
      if (!dryRun) {
        await prisma.$executeRaw`UPDATE study_notes SET title = ${derived.title}, preview = ${derived.preview} WHERE id = ${row.id}::uuid`
      }
    }
    lastId = rows[rows.length - 1].id
  }

  return { scanned, updated }
}

async function main() {
  const dryRun = process.argv.includes('--dry-run')
  console.log(`Backfilling note titles/previews${dryRun ? ' (dry run)' : ''}...`)
  const { scanned, updated } = await backfillNoteTitles({ dryRun })
  console.log(`Scanned ${scanned} notes, ${dryRun ? 'would update' : 'updated'} ${updated}`)
  await prisma.$disconnect()
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch(async (err) => {
    console.error(err)
    await prisma.$disconnect()
    process.exit(1)
  })
}
