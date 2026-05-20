import { PrismaClient } from '../src/generated/prisma/index.js'

const prisma = new PrismaClient()

/**
 * Comprehensive RBAC Seed Script
 *
 * This script:
 * 1. Creates all system permissions
 * 2. Creates all system roles
 * 3. Maps roles to permissions
 * 4. Migrates existing Organization.ownerId to UserRole records
 *
 * Safe to run multiple times (idempotent)
 */

// ============================================================================
// 1. Define all system permissions
// ============================================================================

const PERMISSIONS = [
  // Organization permissions
  { resource: 'organization', action: 'create', name: 'organization.create', description: 'Create new organizations' },
  { resource: 'organization', action: 'read', name: 'organization.read', description: 'View organization details' },
  { resource: 'organization', action: 'update', name: 'organization.update', description: 'Update organization settings' },
  { resource: 'organization', action: 'delete', name: 'organization.delete', description: 'Delete organization' },
  { resource: 'organization', action: 'invite', name: 'organization.invite', description: 'Invite users to organization' },

  // Group permissions
  { resource: 'group', action: 'create', name: 'group.create', description: 'Create new groups' },
  { resource: 'group', action: 'read', name: 'group.read', description: 'View group details' },
  { resource: 'group', action: 'update', name: 'group.update', description: 'Update group settings' },
  { resource: 'group', action: 'delete', name: 'group.delete', description: 'Delete groups' },
  { resource: 'group', action: 'invite', name: 'group.invite', description: 'Invite members to groups' },

  // Member permissions
  { resource: 'member', action: 'create', name: 'member.create', description: 'Add new members' },
  { resource: 'member', action: 'read', name: 'member.read', description: 'View member details' },
  { resource: 'member', action: 'update', name: 'member.update', description: 'Update member information' },
  { resource: 'member', action: 'delete', name: 'member.delete', description: 'Remove members' },

  // Media permissions
  { resource: 'media', action: 'create', name: 'media.create', description: 'Upload media files' },
  { resource: 'media', action: 'read', name: 'media.read', description: 'View media files' },
  { resource: 'media', action: 'update', name: 'media.update', description: 'Update media files' },
  { resource: 'media', action: 'delete', name: 'media.delete', description: 'Delete media files' },
  { resource: 'media', action: 'publish', name: 'media.publish', description: 'Publish media to members' },

  // Role permissions
  { resource: 'role', action: 'create', name: 'role.create', description: 'Create custom roles' },
  { resource: 'role', action: 'read', name: 'role.read', description: 'View roles' },
  { resource: 'role', action: 'update', name: 'role.update', description: 'Update role permissions' },
  { resource: 'role', action: 'delete', name: 'role.delete', description: 'Delete custom roles' },
  { resource: 'role', action: 'assign', name: 'role.assign', description: 'Assign roles to users' },
]

// ============================================================================
// 2. Define system roles and their permissions
// ============================================================================

const SYSTEM_ROLES = [
  {
    name: 'Super Admin',
    description: 'Platform-wide administrator with unlimited access to all organizations',
    isSystem: true,
    organizationId: null, // Platform-wide role
    permissions: 'ALL', // Special marker for all permissions
  },
  {
    name: 'Owner',
    description: 'Organization owner with full control over the organization and all groups',
    isSystem: true,
    organizationId: null, // Created per-organization, but template is system
    permissions: [
      // Organization permissions (full control)
      'organization.read',
      'organization.update',
      'organization.delete',
      'organization.invite',
      // Group permissions (full control, inherited to all groups)
      'group.create',
      'group.read',
      'group.update',
      'group.delete',
      'group.invite',
      // Member permissions (full control)
      'member.create',
      'member.read',
      'member.update',
      'member.delete',
      // Media permissions (full control)
      'media.create',
      'media.read',
      'media.update',
      'media.delete',
      'media.publish',
      // Role permissions
      'role.create',
      'role.read',
      'role.update',
      'role.delete',
      'role.assign',
    ],
  },
  {
    name: 'Admin',
    description: 'Organization administrator with most permissions except organization deletion',
    isSystem: true,
    organizationId: null,
    permissions: [
      // Organization permissions (limited)
      'organization.read',
      'organization.update',
      'organization.invite',
      // Group permissions (full control)
      'group.create',
      'group.read',
      'group.update',
      'group.delete',
      'group.invite',
      // Member permissions (full control)
      'member.create',
      'member.read',
      'member.update',
      'member.delete',
      // Media permissions (full control)
      'media.create',
      'media.read',
      'media.update',
      'media.delete',
      'media.publish',
      // Role permissions (limited - cannot create roles)
      'role.read',
      'role.assign',
    ],
  },
  {
    name: 'Group Leader',
    description: 'Can manage groups and create content',
    isSystem: true,
    organizationId: null,
    permissions: [
      // Group permissions (limited - can manage assigned groups)
      'group.read',
      'group.update',
      'group.invite',
      // Member permissions (within groups only)
      'member.read',
      'member.update',
      // Media permissions (can create and manage)
      'media.create',
      'media.read',
      'media.update',
      'media.delete',
      'media.publish',
    ],
  },
  {
    name: 'Contributor',
    description: 'Can create content but cannot delete or modify others\' content',
    isSystem: true,
    organizationId: null,
    permissions: [
      // Group permissions (read only)
      'group.read',
      // Member permissions (read only)
      'member.read',
      // Media permissions (can create, read own, update own)
      'media.create',
      'media.read',
    ],
  },
]

// ============================================================================
// Main seed function
// ============================================================================

async function main() {
  console.log('🌱 Starting RBAC seed...\n')

  // Step 1: Create all permissions
  console.log('📋 Creating system permissions...')
  const permissionMap = new Map<string, string>() // name -> id

  for (const perm of PERMISSIONS) {
    const permission = await prisma.permission.upsert({
      where: { name: perm.name },
      update: {
        resource: perm.resource,
        action: perm.action,
        description: perm.description,
      },
      create: perm,
    })
    permissionMap.set(permission.name, permission.id)
    console.log(`  ✓ ${perm.name}`)
  }

  console.log(`\n✅ Created ${PERMISSIONS.length} permissions\n`)

  // Step 2: Create all system roles
  console.log('👥 Creating system roles...')
  const roleMap = new Map<string, string>() // name -> id

  for (const roleTemplate of SYSTEM_ROLES) {
    // Find existing system role (where organizationId is null)
    let role = await prisma.role.findFirst({
      where: {
        name: roleTemplate.name,
        organizationId: null,
      },
    })

    if (role) {
      // Update existing role
      role = await prisma.role.update({
        where: { id: role.id },
        data: {
          description: roleTemplate.description,
          isSystem: roleTemplate.isSystem,
        },
      })
    } else {
      // Create new role
      role = await prisma.role.create({
        data: {
          name: roleTemplate.name,
          description: roleTemplate.description,
          isSystem: roleTemplate.isSystem,
          organizationId: null,
        },
      })
    }

    roleMap.set(role.name, role.id)
    console.log(`  ✓ ${roleTemplate.name}`)
  }

  console.log(`\n✅ Created ${SYSTEM_ROLES.length} system roles\n`)

  // Step 3: Map roles to permissions
  console.log('🔗 Mapping roles to permissions...')

  for (const roleTemplate of SYSTEM_ROLES) {
    const roleId = roleMap.get(roleTemplate.name)
    if (!roleId) continue

    // Handle "ALL" permissions for Super Admin
    if (roleTemplate.permissions === 'ALL') {
      console.log(`  ⚡ ${roleTemplate.name}: ALL PERMISSIONS`)

      // Delete existing role permissions
      await prisma.rolePermission.deleteMany({
        where: { roleId },
      })

      // Assign all permissions
      for (const [permName, permId] of permissionMap.entries()) {
        await prisma.rolePermission.upsert({
          where: {
            roleId_permissionId: {
              roleId,
              permissionId: permId,
            },
          },
          update: {},
          create: {
            roleId,
            permissionId: permId,
          },
        })
      }
      console.log(`    → Assigned ${permissionMap.size} permissions`)
      continue
    }

    // Handle specific permission lists
    const permissions = roleTemplate.permissions as string[]
    console.log(`  🔐 ${roleTemplate.name}: ${permissions.length} permissions`)

    // Delete existing role permissions
    await prisma.rolePermission.deleteMany({
      where: { roleId },
    })

    // Assign specified permissions
    for (const permName of permissions) {
      const permId = permissionMap.get(permName)
      if (!permId) {
        console.warn(`    ⚠️  Permission not found: ${permName}`)
        continue
      }

      await prisma.rolePermission.upsert({
        where: {
          roleId_permissionId: {
            roleId,
            permissionId: permId,
          },
        },
        update: {},
        create: {
          roleId,
          permissionId: permId,
        },
      })
    }
  }

  console.log('\n✅ Role-permission mappings complete\n')

  // Step 4: Migrate existing Organization.ownerId to UserRole records
  console.log('📦 Migrating existing organization owners to UserRole...')

  const organizations = await prisma.organization.findMany()

  console.log(`  Found ${organizations.length} organizations with owners`)

  const ownerRoleId = roleMap.get('Owner')
  if (!ownerRoleId) {
    console.error('  ❌ Owner role not found, skipping migration')
  } else {
    let migratedCount = 0

    for (const org of organizations) {
      // Check if UserRole already exists
      const existing = await prisma.userRole.findUnique({
        where: {
          userId_roleId_organizationId: {
            userId: org.ownerId,
            roleId: ownerRoleId,
            organizationId: org.id,
          },
        },
      })

      if (existing) {
        console.log(`  ↷ Organization "${org.name}": Owner role already exists`)
        continue
      }

      // Create UserRole for owner
      await prisma.userRole.create({
        data: {
          userId: org.ownerId,
          roleId: ownerRoleId,
          organizationId: org.id,
          assignedBy: org.ownerId, // Self-assigned
        },
      })

      migratedCount++
      console.log(`  ✓ Organization "${org.name}": Created Owner role for user ${org.ownerId.slice(0, 8)}...`)
    }

    console.log(`\n✅ Migrated ${migratedCount} organization owners to UserRole\n`)
  }

  // Step 5: Summary
  console.log('═══════════════════════════════════════')
  console.log('🎉 RBAC Seed Complete!')
  console.log('═══════════════════════════════════════')
  console.log(`✅ ${PERMISSIONS.length} permissions created`)
  console.log(`✅ ${SYSTEM_ROLES.length} system roles created`)
  console.log(`✅ Role-permission mappings complete`)
  console.log(`✅ Organization owners migrated to UserRole`)
  console.log('═══════════════════════════════════════\n')
}

// Run the seed function
main()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error('❌ Seed failed:', e)
    await prisma.$disconnect()
    process.exit(1)
  })
