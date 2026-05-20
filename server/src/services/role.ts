import { prisma } from '../lib/prisma.js'

/**
 * Role Service - Role and Permission Management
 *
 * Handles CRUD operations for roles and role assignments
 */

// ============================================================================
// Role Management (CRUD)
// ============================================================================

/**
 * Get all roles for an organization (includes system roles)
 */
export async function getOrganizationRoles(organizationId: string) {
  try {
    // Get organization-specific roles AND system roles (organizationId = null)
    const roles = await prisma.role.findMany({
      where: {
        OR: [
          { organizationId },
          { organizationId: null, isSystem: true },
        ],
      },
      include: {
        permissions: {
          include: {
            permission: true,
          },
        },
        _count: {
          select: {
            userRoles: true,
          },
        },
      },
      orderBy: [{ isSystem: 'desc' }, { name: 'asc' }],
    })

    return {
      success: true,
      data: roles,
    }
  } catch (error) {
    console.error('Error fetching organization roles:', error)
    return {
      success: false,
      error: 'Failed to fetch roles',
    }
  }
}

/**
 * Get a specific role with permissions
 */
export async function getRole(roleId: string) {
  try {
    const role = await prisma.role.findUnique({
      where: { id: roleId },
      include: {
        permissions: {
          include: {
            permission: true,
          },
        },
        userRoles: {
          include: {
            user: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
          },
        },
      },
    })

    if (!role) {
      return {
        success: false,
        error: 'Role not found',
      }
    }

    return {
      success: true,
      data: role,
    }
  } catch (error) {
    console.error('Error fetching role:', error)
    return {
      success: false,
      error: 'Failed to fetch role',
    }
  }
}

/**
 * Create a custom role for an organization
 */
export async function createRole(
  organizationId: string,
  name: string,
  description?: string
) {
  try {
    // Check if role name already exists in this organization
    const existing = await prisma.role.findUnique({
      where: {
        name_organizationId: {
          name,
          organizationId,
        },
      },
    })

    if (existing) {
      return {
        success: false,
        error: 'A role with this name already exists in this organization',
      }
    }

    const role = await prisma.role.create({
      data: {
        name,
        description,
        organizationId,
        isSystem: false,
      },
    })

    return {
      success: true,
      data: role,
    }
  } catch (error) {
    console.error('Error creating role:', error)
    return {
      success: false,
      error: 'Failed to create role',
    }
  }
}

/**
 * Update a custom role (system roles cannot be updated)
 */
export async function updateRole(
  roleId: string,
  name?: string,
  description?: string
) {
  try {
    // Check if role exists and is not a system role
    const role = await prisma.role.findUnique({
      where: { id: roleId },
    })

    if (!role) {
      return {
        success: false,
        error: 'Role not found',
      }
    }

    if (role.isSystem) {
      return {
        success: false,
        error: 'System roles cannot be modified',
      }
    }

    // If name is being changed, check for conflicts
    if (name && name !== role.name) {
      const existing = await prisma.role.findUnique({
        where: {
          name_organizationId: {
            name,
            organizationId: role.organizationId!,
          },
        },
      })

      if (existing) {
        return {
          success: false,
          error: 'A role with this name already exists in this organization',
        }
      }
    }

    const updated = await prisma.role.update({
      where: { id: roleId },
      data: {
        ...(name && { name }),
        ...(description !== undefined && { description }),
      },
    })

    return {
      success: true,
      data: updated,
    }
  } catch (error) {
    console.error('Error updating role:', error)
    return {
      success: false,
      error: 'Failed to update role',
    }
  }
}

/**
 * Delete a custom role (system roles cannot be deleted)
 */
export async function deleteRole(roleId: string) {
  try {
    // Check if role exists and is not a system role
    const role = await prisma.role.findUnique({
      where: { id: roleId },
      include: {
        _count: {
          select: {
            userRoles: true,
          },
        },
      },
    })

    if (!role) {
      return {
        success: false,
        error: 'Role not found',
      }
    }

    if (role.isSystem) {
      return {
        success: false,
        error: 'System roles cannot be deleted',
      }
    }

    if (role._count.userRoles > 0) {
      return {
        success: false,
        error: `Cannot delete role: ${role._count.userRoles} users are assigned to this role`,
      }
    }

    await prisma.role.delete({
      where: { id: roleId },
    })

    return {
      success: true,
      data: { message: 'Role deleted successfully' },
    }
  } catch (error) {
    console.error('Error deleting role:', error)
    return {
      success: false,
      error: 'Failed to delete role',
    }
  }
}

// ============================================================================
// Permission Management
// ============================================================================

/**
 * Get all available permissions
 */
export async function getAllPermissions() {
  try {
    const permissions = await prisma.permission.findMany({
      orderBy: [{ resource: 'asc' }, { action: 'asc' }],
    })

    return {
      success: true,
      data: permissions,
    }
  } catch (error) {
    console.error('Error fetching permissions:', error)
    return {
      success: false,
      error: 'Failed to fetch permissions',
    }
  }
}

/**
 * Get permissions for a specific role
 */
export async function getRolePermissions(roleId: string) {
  try {
    const rolePermissions = await prisma.rolePermission.findMany({
      where: { roleId },
      include: {
        permission: true,
      },
    })

    return {
      success: true,
      data: rolePermissions.map((rp) => rp.permission),
    }
  } catch (error) {
    console.error('Error fetching role permissions:', error)
    return {
      success: false,
      error: 'Failed to fetch role permissions',
    }
  }
}

/**
 * Update permissions for a custom role
 */
export async function updateRolePermissions(
  roleId: string,
  permissionIds: string[]
) {
  try {
    // Check if role exists and is not a system role
    const role = await prisma.role.findUnique({
      where: { id: roleId },
    })

    if (!role) {
      return {
        success: false,
        error: 'Role not found',
      }
    }

    if (role.isSystem) {
      return {
        success: false,
        error: 'System role permissions cannot be modified',
      }
    }

    // Verify all permission IDs exist
    const permissions = await prisma.permission.findMany({
      where: { id: { in: permissionIds } },
    })

    if (permissions.length !== permissionIds.length) {
      return {
        success: false,
        error: 'One or more permission IDs are invalid',
      }
    }

    // Delete existing permissions and create new ones in a transaction
    await prisma.$transaction([
      prisma.rolePermission.deleteMany({
        where: { roleId },
      }),
      prisma.rolePermission.createMany({
        data: permissionIds.map((permissionId) => ({
          roleId,
          permissionId,
        })),
      }),
    ])

    // Return updated permissions
    return await getRolePermissions(roleId)
  } catch (error) {
    console.error('Error updating role permissions:', error)
    return {
      success: false,
      error: 'Failed to update role permissions',
    }
  }
}

// ============================================================================
// User Role Assignment
// ============================================================================

/**
 * Get all role assignments for a user in an organization
 */
export async function getUserRoles(userId: string, organizationId: string) {
  try {
    const userRoles = await prisma.userRole.findMany({
      where: {
        userId,
        organizationId,
      },
      include: {
        role: {
          include: {
            permissions: {
              include: {
                permission: true,
              },
            },
          },
        },
      },
    })

    return {
      success: true,
      data: userRoles,
    }
  } catch (error) {
    console.error('Error fetching user roles:', error)
    return {
      success: false,
      error: 'Failed to fetch user roles',
    }
  }
}

/**
 * Get all users with a specific role in an organization
 */
export async function getUsersWithRole(roleId: string, organizationId: string) {
  try {
    const userRoles = await prisma.userRole.findMany({
      where: {
        roleId,
        organizationId,
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            picture: true,
          },
        },
        role: true,
      },
    })

    return {
      success: true,
      data: userRoles,
    }
  } catch (error) {
    console.error('Error fetching users with role:', error)
    return {
      success: false,
      error: 'Failed to fetch users with role',
    }
  }
}

/**
 * Assign a role to a user
 */
export async function assignRole(
  userId: string,
  roleId: string,
  organizationId: string,
  assignedBy: string
) {
  try {
    // Verify user exists
    const user = await prisma.user.findUnique({
      where: { id: userId },
    })

    if (!user) {
      return {
        success: false,
        error: 'User not found',
      }
    }

    // Verify role exists
    const role = await prisma.role.findUnique({
      where: { id: roleId },
    })

    if (!role) {
      return {
        success: false,
        error: 'Role not found',
      }
    }

    // If role is organization-specific, verify it belongs to the target organization
    if (role.organizationId && role.organizationId !== organizationId) {
      return {
        success: false,
        error: 'Role does not belong to this organization',
      }
    }

    // Check if user already has this role
    const existing = await prisma.userRole.findUnique({
      where: {
        userId_roleId_organizationId: {
          userId,
          roleId,
          organizationId,
        },
      },
    })

    if (existing) {
      return {
        success: false,
        error: 'User already has this role',
      }
    }

    // Create role assignment
    const userRole = await prisma.userRole.create({
      data: {
        userId,
        roleId,
        organizationId,
        assignedBy,
      },
      include: {
        role: true,
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    })

    return {
      success: true,
      data: userRole,
    }
  } catch (error) {
    console.error('Error assigning role:', error)
    return {
      success: false,
      error: 'Failed to assign role',
    }
  }
}

/**
 * Remove a role from a user
 */
export async function removeRole(
  userId: string,
  roleId: string,
  organizationId: string
) {
  try {
    // Check if assignment exists
    const userRole = await prisma.userRole.findUnique({
      where: {
        userId_roleId_organizationId: {
          userId,
          roleId,
          organizationId,
        },
      },
      include: {
        role: true,
      },
    })

    if (!userRole) {
      return {
        success: false,
        error: 'User does not have this role',
      }
    }

    // Delete role assignment
    await prisma.userRole.delete({
      where: {
        userId_roleId_organizationId: {
          userId,
          roleId,
          organizationId,
        },
      },
    })

    return {
      success: true,
      data: { message: 'Role removed successfully' },
    }
  } catch (error) {
    console.error('Error removing role:', error)
    return {
      success: false,
      error: 'Failed to remove role',
    }
  }
}
