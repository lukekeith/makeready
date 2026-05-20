/**
 * Test script for RBAC permission system
 *
 * This script tests the permission checking logic with different scenarios
 */

import { prisma } from '../src/lib/prisma.js'
import {
  hasPermission,
  isSuperAdmin,
  getUserRolesForOrg,
  getPermissionsForRole,
  isOrganizationMember,
  isGroupMember,
} from '../src/services/permission.js'

async function main() {
  console.log('\n🧪 Testing RBAC Permission System\n')
  console.log('═'.repeat(50))

  // Get test data
  const organizations = await prisma.organization.findMany({
    take: 1,
    include: {
      owner: true,
    },
  })

  if (organizations.length === 0) {
    console.log('❌ No organizations found. Please create test data first.')
    return
  }

  const org = organizations[0]
  const ownerId = org.ownerId

  console.log(`\n📊 Test Data:`)
  console.log(`  Organization: ${org.name}`)
  console.log(`  Owner: ${org.owner.name} (${org.owner.email})`)
  console.log(`  Owner ID: ${ownerId}`)
  console.log(`  Org ID: ${org.id}\n`)

  // Test 1: Check user's roles
  console.log('─'.repeat(50))
  console.log('Test 1: Get User Roles for Organization')
  console.log('─'.repeat(50))
  const userRoles = await getUserRolesForOrg(ownerId, org.id)
  console.log(`✓ User has ${userRoles.length} role(s):`)
  userRoles.forEach((role) => {
    console.log(`  - ${role.name} (${role.isSystem ? 'System' : 'Custom'})`)
  })

  // Test 2: Get permissions for Owner role
  console.log('\n' + '─'.repeat(50))
  console.log('Test 2: Get Permissions for Owner Role')
  console.log('─'.repeat(50))
  const ownerRole = await prisma.role.findFirst({
    where: {
      name: 'Owner',
      organizationId: null,
    },
  })

  if (ownerRole) {
    const permissions = await getPermissionsForRole(ownerRole.id)
    console.log(`✓ Owner role has ${permissions.length} permissions:`)
    permissions.slice(0, 10).forEach((perm) => {
      console.log(`  - ${perm}`)
    })
    if (permissions.length > 10) {
      console.log(`  ... and ${permissions.length - 10} more`)
    }
  }

  // Test 3: Check specific permissions
  console.log('\n' + '─'.repeat(50))
  console.log('Test 3: Check Specific Permissions')
  console.log('─'.repeat(50))

  const permissionsToTest = [
    { perm: 'organization.read', type: 'organization', id: org.id },
    { perm: 'organization.update', type: 'organization', id: org.id },
    { perm: 'organization.delete', type: 'organization', id: org.id },
    { perm: 'group.create', type: 'organization', id: org.id },
    { perm: 'member.read', type: 'organization', id: org.id },
    { perm: 'media.create', type: 'organization', id: org.id },
    { perm: 'role.create', type: 'organization', id: org.id },
  ]

  for (const { perm, type, id } of permissionsToTest) {
    const hasAccess = await hasPermission({ userId: ownerId }, perm, type, id)
    console.log(`${hasAccess ? '✓' : '✗'} ${perm}: ${hasAccess ? 'GRANTED' : 'DENIED'}`)
  }

  // Test 4: Check Super Admin
  console.log('\n' + '─'.repeat(50))
  console.log('Test 4: Check Super Admin Status')
  console.log('─'.repeat(50))
  const isSuper = await isSuperAdmin(ownerId)
  console.log(`${isSuper ? '✓' : '✗'} User is Super Admin: ${isSuper}`)

  // Test 5: Test role hierarchy
  console.log('\n' + '─'.repeat(50))
  console.log('Test 5: Role Hierarchy Comparison')
  console.log('─'.repeat(50))

  const roles = await prisma.role.findMany({
    where: { organizationId: null },
    include: {
      permissions: {
        include: {
          permission: true,
        },
      },
    },
  })

  console.log('\nRole Permission Summary:')
  roles.forEach((role) => {
    console.log(`  ${role.name}: ${role.permissions.length} permissions`)
  })

  // Test 6: Verify all system roles exist
  console.log('\n' + '─'.repeat(50))
  console.log('Test 6: Verify System Roles')
  console.log('─'.repeat(50))

  const expectedRoles = ['Super Admin', 'Owner', 'Admin', 'Group Leader', 'Contributor']
  for (const roleName of expectedRoles) {
    const role = await prisma.role.findFirst({
      where: {
        name: roleName,
        organizationId: null,
      },
    })
    console.log(`${role ? '✓' : '✗'} ${roleName}: ${role ? 'EXISTS' : 'MISSING'}`)
  }

  // Test 7: Verify all permissions exist
  console.log('\n' + '─'.repeat(50))
  console.log('Test 7: Verify Permissions')
  console.log('─'.repeat(50))

  const allPermissions = await prisma.permission.findMany({
    orderBy: { name: 'asc' },
  })

  console.log(`✓ Total permissions in database: ${allPermissions.length}`)

  const permissionsByResource = allPermissions.reduce((acc, perm) => {
    if (!acc[perm.resource]) {
      acc[perm.resource] = []
    }
    acc[perm.resource].push(perm.action)
    return acc
  }, {} as Record<string, string[]>)

  console.log('\nPermissions by resource:')
  Object.entries(permissionsByResource).forEach(([resource, actions]) => {
    console.log(`  ${resource}: ${actions.join(', ')}`)
  })

  console.log('\n' + '═'.repeat(50))
  console.log('✅ Permission System Tests Complete\n')
}

main()
  .catch((error) => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
