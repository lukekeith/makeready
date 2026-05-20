/**
 * E2E Test Data Seed
 *
 * This script creates test data specifically for E2E tests running in CI.
 * It should ONLY be run in the E2E test environment (docker-compose.test.yml).
 *
 * Creates:
 * - A test user
 * - A test organization
 * - A test group with code "TEST01" (matches e2e/fixtures/test-data.ts)
 *
 * Uses ES modules (.mjs) so it can run directly with `node` without TypeScript compilation.
 */

import { PrismaClient } from '../dist/generated/prisma/index.js'

const prisma = new PrismaClient()

const TEST_USER = {
  id: 'e2e-test-user-id',
  googleId: 'e2e-test-google-id',
  email: 'e2e-test@makeready.test',
  name: 'E2E Test User',
}

const TEST_ORGANIZATION = {
  id: 'e2e-test-org-id',
  name: 'E2E Test Organization',
}

const TEST_GROUP = {
  id: 'e2e-test-group-id',
  code: 'TEST01',      // Must match TEST_GROUPS.valid.code in client/e2e/fixtures/test-data.ts
  name: 'Test Group',  // Must match TEST_GROUPS.valid.name in client/e2e/fixtures/test-data.ts
  description: 'A test group for E2E testing',
  welcomeMessage: 'Welcome to the test group!',
}

async function main() {
  console.log('🧪 Starting E2E test data seed...\n')

  // Step 1: Create test user
  console.log('👤 Creating test user...')
  const user = await prisma.user.upsert({
    where: { id: TEST_USER.id },
    update: {
      googleId: TEST_USER.googleId,
      email: TEST_USER.email,
      name: TEST_USER.name,
    },
    create: {
      id: TEST_USER.id,
      googleId: TEST_USER.googleId,
      email: TEST_USER.email,
      name: TEST_USER.name,
    },
  })
  console.log(`  ✓ User created: ${user.email}`)

  // Step 2: Create test organization
  console.log('🏢 Creating test organization...')
  const organization = await prisma.organization.upsert({
    where: { id: TEST_ORGANIZATION.id },
    update: {
      name: TEST_ORGANIZATION.name,
      ownerId: user.id,
    },
    create: {
      id: TEST_ORGANIZATION.id,
      name: TEST_ORGANIZATION.name,
      ownerId: user.id,
    },
  })
  console.log(`  ✓ Organization created: ${organization.name}`)

  // Step 3: Create test group
  console.log('👥 Creating test group...')
  const group = await prisma.group.upsert({
    where: { id: TEST_GROUP.id },
    update: {
      code: TEST_GROUP.code,
      name: TEST_GROUP.name,
      description: TEST_GROUP.description,
      welcomeMessage: TEST_GROUP.welcomeMessage,
      creatorId: user.id,
      organizationId: organization.id,
    },
    create: {
      id: TEST_GROUP.id,
      code: TEST_GROUP.code,
      name: TEST_GROUP.name,
      description: TEST_GROUP.description,
      welcomeMessage: TEST_GROUP.welcomeMessage,
      creatorId: user.id,
      organizationId: organization.id,
    },
  })
  console.log(`  ✓ Group created: ${group.name} (code: ${group.code})`)

  // Summary
  console.log('\n═══════════════════════════════════════')
  console.log('🎉 E2E Test Data Seed Complete!')
  console.log('═══════════════════════════════════════')
  console.log(`✅ User: ${user.email}`)
  console.log(`✅ Organization: ${organization.name}`)
  console.log(`✅ Group: ${group.name} (code: ${group.code})`)
  console.log('═══════════════════════════════════════\n')
}

// Run the seed function
main()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error('❌ E2E seed failed:', e)
    await prisma.$disconnect()
    process.exit(1)
  })
