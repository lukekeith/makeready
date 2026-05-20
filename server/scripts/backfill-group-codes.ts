/**
 * Backfill script to add unique codes to all existing groups
 * Run with: npx tsx scripts/backfill-group-codes.ts
 */

import { prisma } from '../src/lib/prisma.js'
import { generateGroupCode } from '../src/lib/group-code.js'

async function backfillGroupCodes() {
  console.log('🔄 Starting group code backfill...')

  // First, check if the column exists by trying to query it
  try {
    // Try to add the column if it doesn't exist
    await prisma.$executeRaw`
      ALTER TABLE "groups" ADD COLUMN IF NOT EXISTS "code" VARCHAR(6)
    `
    console.log('✅ Ensured code column exists')
  } catch (error) {
    console.log('ℹ️ Column may already exist, continuing...')
  }

  // Get all groups that don't have a code yet
  const groupsWithoutCode = await prisma.$queryRaw<{ id: string }[]>`
    SELECT id FROM "groups" WHERE "code" IS NULL
  `

  console.log(`📊 Found ${groupsWithoutCode.length} groups without codes`)

  // Track used codes to avoid collisions within this batch
  const usedCodes = new Set<string>()

  // First, get all existing codes
  const existingCodes = await prisma.$queryRaw<{ code: string }[]>`
    SELECT "code" FROM "groups" WHERE "code" IS NOT NULL
  `
  existingCodes.forEach((row) => usedCodes.add(row.code))

  // Generate unique code for each group
  for (const group of groupsWithoutCode) {
    let code = generateGroupCode()
    let attempts = 0

    // Ensure uniqueness
    while (usedCodes.has(code)) {
      code = generateGroupCode()
      attempts++
      if (attempts > 100) {
        throw new Error(`Failed to generate unique code for group ${group.id}`)
      }
    }

    usedCodes.add(code)

    // Update the group
    await prisma.$executeRaw`
      UPDATE "groups" SET "code" = ${code} WHERE "id" = ${group.id}
    `
    console.log(`  ✅ Group ${group.id} → ${code}`)
  }

  console.log('✅ Backfill complete!')

  // Now add the unique constraint if it doesn't exist
  try {
    await prisma.$executeRaw`
      ALTER TABLE "groups" ADD CONSTRAINT "groups_code_key" UNIQUE ("code")
    `
    console.log('✅ Added unique constraint on code column')
  } catch (error) {
    console.log('ℹ️ Unique constraint may already exist')
  }

  // Verify all groups have codes
  const nullCodes = await prisma.$queryRaw<{ count: bigint }[]>`
    SELECT COUNT(*) as count FROM "groups" WHERE "code" IS NULL
  `
  const nullCount = Number(nullCodes[0]?.count || 0)

  if (nullCount > 0) {
    console.error(`❌ Warning: ${nullCount} groups still have NULL codes`)
  } else {
    console.log('✅ All groups have codes!')
  }
}

backfillGroupCodes()
  .then(() => {
    console.log('🎉 Done!')
    process.exit(0)
  })
  .catch((error) => {
    console.error('❌ Error:', error)
    process.exit(1)
  })
