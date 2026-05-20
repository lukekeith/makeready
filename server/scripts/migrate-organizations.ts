/**
 * Data Migration Script: Create organizations for existing users
 *
 * This script should be run AFTER the schema migration is applied.
 * It will:
 * 1. Create an organization for each existing user (if not already created)
 * 2. Link users to their organizations
 * 3. Update all groups to belong to the creator's organization
 *
 * Run with: npx tsx scripts/migrate-organizations.ts
 */

import { prisma } from '../src/lib/prisma.js'

async function migrateOrganizations() {
  console.log('Starting organization migration...\n')

  try {
    // Get all existing users
    const users = await prisma.user.findMany({
      include: {
        createdGroups: true,
      },
    })

    console.log(`Found ${users.length} users to migrate\n`)

    let organizationsCreated = 0
    let groupsUpdated = 0

    // For each user, create an organization and update their groups
    for (const user of users) {
      console.log(`Processing user: ${user.name} (${user.email})`)

      // Check if organization already exists for this user
      let organization = await prisma.organization.findUnique({
        where: { ownerId: user.id },
      })

      if (!organization) {
        // Create organization for this user
        organization = await prisma.organization.create({
          data: {
            name: user.name, // Default organization name to user's name
            ownerId: user.id,
            isActive: true,
          },
        })
        organizationsCreated++
        console.log(`  ✓ Created organization: ${organization.name}`)
      } else {
        console.log(`  • Organization already exists: ${organization.name}`)
      }

      // Link user to their organization (if not already linked)
      if (user.organizationId !== organization.id) {
        await prisma.user.update({
          where: { id: user.id },
          data: { organizationId: organization.id },
        })
        console.log(`  ✓ Linked user to organization`)
      }

      // Update all groups created by this user to belong to their organization
      const groupsToUpdate = user.createdGroups.filter(
        (group) => !group.organizationId
      )

      if (groupsToUpdate.length > 0) {
        await prisma.group.updateMany({
          where: {
            id: { in: groupsToUpdate.map((g) => g.id) },
          },
          data: {
            organizationId: organization.id,
          },
        })
        groupsUpdated += groupsToUpdate.length
        console.log(`  ✓ Updated ${groupsToUpdate.length} groups`)
      }

      console.log('') // Empty line for readability
    }

    console.log('\n=== Migration Summary ===')
    console.log(`Organizations created: ${organizationsCreated}`)
    console.log(`Groups updated: ${groupsUpdated}`)
    console.log(`Total users processed: ${users.length}`)
    console.log('\n✓ Migration completed successfully!')

    // Verify no users are left without organizations
    const usersWithoutOrg = await prisma.user.count({
      where: { organizationId: null },
    })

    if (usersWithoutOrg > 0) {
      console.warn(
        `\n⚠️  Warning: ${usersWithoutOrg} users still without organization!`
      )
    }

    // Verify no groups are left without organizations
    const groupsWithoutOrg = await prisma.group.count({
      where: { organizationId: null },
    })

    if (groupsWithoutOrg > 0) {
      console.warn(
        `\n⚠️  Warning: ${groupsWithoutOrg} groups still without organization!`
      )
    }

    if (usersWithoutOrg === 0 && groupsWithoutOrg === 0) {
      console.log('\n✓ All users and groups have organizations assigned!')
      console.log('\nNext steps:')
      console.log('1. Review the migration results above')
      console.log(
        '2. Uncomment the foreign key constraints in the migration file'
      )
      console.log('3. Run: npx prisma migrate resolve --applied <migration_name>')
      console.log('4. Test the API endpoints to ensure everything works')
    }
  } catch (error) {
    console.error('\n❌ Migration failed:', error)
    throw error
  } finally {
    await prisma.$disconnect()
  }
}

// Run the migration
migrateOrganizations()
  .then(() => {
    console.log('\nMigration script completed.')
    process.exit(0)
  })
  .catch((error) => {
    console.error('\nMigration script failed:', error)
    process.exit(1)
  })
