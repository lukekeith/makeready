/**
 * Backfill script: Set organizationId on study programs that were created
 * with a null org because the create route only stamped the org for org
 * OWNERS. Programs created by group leaders (or other role-holders) got
 * organizationId = null and were invisible to org-scoped reads.
 *
 * For each program with organizationId = null, resolves the creator's org
 * via getUserOrgId (owner, member, or UserRole holder) and stamps it.
 * Programs whose creator has no org affiliation are left untouched.
 *
 * Run with: npx tsx src/scripts/backfill-program-org.ts
 * Add --dry-run to preview without writing.
 */

import { getUserOrgId } from '../services/media-library.js'
import { prisma } from '../lib/prisma.js'

const dryRun = process.argv.includes('--dry-run')

async function main() {
  console.log(`Backfilling program organizationId${dryRun ? ' (dry run)' : ''}...`)

  const orphans = await prisma.studyProgram.findMany({
    where: { organizationId: null },
    select: { id: true, name: true, creatorId: true },
  })
  console.log(`Found ${orphans.length} programs with no organization`)

  let updated = 0
  let skipped = 0
  for (const program of orphans) {
    const orgId = await getUserOrgId(program.creatorId)
    if (!orgId) {
      skipped++
      continue
    }

    console.log(`  ${dryRun ? 'Would set' : 'Setting'} org ${orgId} on "${program.name}" (${program.id})`)
    if (!dryRun) {
      await prisma.studyProgram.update({
        where: { id: program.id },
        data: { organizationId: orgId },
      })
    }
    updated++
  }

  console.log(`✓ ${dryRun ? 'Would update' : 'Updated'} ${updated} programs, skipped ${skipped} (creator has no org)`)
}

main()
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
