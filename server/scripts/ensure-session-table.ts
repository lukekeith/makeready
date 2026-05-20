/**
 * Ensures the session table exists in the database.
 *
 * The session table is used by connect-pg-simple for Express session storage.
 * It is NOT managed by Prisma, so it can be accidentally dropped during migrations.
 *
 * Run this script:
 * - After any `prisma migrate reset`
 * - After any database reset or restore
 * - During server startup (automatic)
 *
 * Usage: npx tsx scripts/ensure-session-table.ts
 */

import { PrismaClient } from '../src/generated/prisma'

const prisma = new PrismaClient()

async function ensureSessionTable(): Promise<void> {
  console.log('🔍 Checking for session table...')

  try {
    // Check if session table exists
    const result = await prisma.$queryRaw<{ exists: boolean }[]>`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'session'
      ) as exists
    `

    if (result[0]?.exists) {
      console.log('✅ Session table already exists')
      return
    }

    // Create session table
    console.log('📦 Creating session table...')
    await prisma.$executeRaw`
      CREATE TABLE IF NOT EXISTS session (
        sid VARCHAR NOT NULL PRIMARY KEY,
        sess JSON NOT NULL,
        expire TIMESTAMP(6) NOT NULL
      )
    `

    // Create index
    await prisma.$executeRaw`
      CREATE INDEX IF NOT EXISTS IDX_session_expire ON session (expire)
    `

    console.log('✅ Session table created successfully')
  } catch (error) {
    console.error('❌ Failed to ensure session table:', error)
    throw error
  } finally {
    await prisma.$disconnect()
  }
}

// Run if called directly
ensureSessionTable()
  .then(() => process.exit(0))
  .catch(() => process.exit(1))

export { ensureSessionTable }
