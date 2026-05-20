import { Router } from 'express'
import { z } from 'zod'
import {
  getOrganizationRoles,
  getRole,
  createRole,
  updateRole,
  deleteRole,
  getAllPermissions,
  getRolePermissions,
  updateRolePermissions,
  getUserRoles,
  getUsersWithRole,
  assignRole,
  removeRole,
} from '../services/role.js'
import { requireAuth, requirePermission } from '../middleware/auth.js'

const router = Router()

// ============================================================================
// Role CRUD Endpoints
// ============================================================================

/**
 * @openapi
 * /api/organizations/{organizationId}/roles:
 *   get:
 *     summary: Get all roles for an organization
 *     description: Retrieves all roles (system and custom) available in the specified organization
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *     responses:
 *       200:
 *         description: Roles retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         example: "role_abc123"
 *                       name:
 *                         type: string
 *                         example: "Admin"
 *                       description:
 *                         type: string
 *                         example: "Full administrative access"
 *                       isSystem:
 *                         type: boolean
 *                         example: true
 *                       organizationId:
 *                         type: string
 *                         nullable: true
 *                         example: "org_abc123"
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                       updatedAt:
 *                         type: string
 *                         format: date-time
 *                 count:
 *                   type: integer
 *                   example: 5
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.read required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
router.get(
  '/organizations/:organizationId/roles',
  requireAuth,
  requirePermission('role.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params

      const result = await getOrganizationRoles(organizationId)

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
        count: result.data?.length || 0,
      })
    } catch (error) {
      console.error('Error fetching organization roles:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/roles/{roleId}:
 *   get:
 *     summary: Get role details
 *     description: Retrieves detailed information about a specific role including its permissions and assigned users
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: string
 *         description: The role ID
 *         example: "role_abc123"
 *     responses:
 *       200:
 *         description: Role details retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       example: "role_abc123"
 *                     name:
 *                       type: string
 *                       example: "Admin"
 *                     description:
 *                       type: string
 *                       example: "Full administrative access"
 *                     isSystem:
 *                       type: boolean
 *                       example: true
 *                     organizationId:
 *                       type: string
 *                       nullable: true
 *                       example: "org_abc123"
 *                     permissions:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                           code:
 *                             type: string
 *                           name:
 *                             type: string
 *                           description:
 *                             type: string
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                     updatedAt:
 *                       type: string
 *                       format: date-time
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.read required"
 *       404:
 *         description: Role not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Role not found"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
router.get(
  '/organizations/:organizationId/roles/:roleId',
  requireAuth,
  requirePermission('role.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { roleId } = req.params

      const result = await getRole(roleId)

      if (!result.success) {
        return res.status(404).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error fetching role:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/roles:
 *   post:
 *     summary: Create a custom role
 *     description: Creates a new custom role for the specified organization
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *                 minLength: 1
 *                 description: The name of the role
 *                 example: "Content Manager"
 *               description:
 *                 type: string
 *                 description: A description of the role's purpose
 *                 example: "Can manage content and lessons"
 *     responses:
 *       201:
 *         description: Role created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       example: "role_xyz789"
 *                     name:
 *                       type: string
 *                       example: "Content Manager"
 *                     description:
 *                       type: string
 *                       example: "Can manage content and lessons"
 *                     isSystem:
 *                       type: boolean
 *                       example: false
 *                     organizationId:
 *                       type: string
 *                       example: "org_abc123"
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                     updatedAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Invalid request body or role creation failed
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Role name is required"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.create required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
const createRoleSchema = z.object({
  name: z.string().min(1, 'Role name is required'),
  description: z.string().optional(),
})

router.post(
  '/organizations/:organizationId/roles',
  requireAuth,
  requirePermission('role.create', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { organizationId } = req.params

      // Validate request body
      const validation = createRoleSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({
          success: false,
          error: validation.error.errors[0].message,
        })
      }

      const { name, description } = validation.data

      const result = await createRole(organizationId, name, description)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.status(201).json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error creating role:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/roles/{roleId}:
 *   patch:
 *     summary: Update a custom role
 *     description: Updates the name and/or description of a custom role. System roles cannot be modified.
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: string
 *         description: The role ID
 *         example: "role_xyz789"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 minLength: 1
 *                 description: The updated name of the role
 *                 example: "Senior Content Manager"
 *               description:
 *                 type: string
 *                 description: The updated description of the role
 *                 example: "Can manage all content and approve changes"
 *     responses:
 *       200:
 *         description: Role updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       example: "role_xyz789"
 *                     name:
 *                       type: string
 *                       example: "Senior Content Manager"
 *                     description:
 *                       type: string
 *                       example: "Can manage all content and approve changes"
 *                     isSystem:
 *                       type: boolean
 *                       example: false
 *                     organizationId:
 *                       type: string
 *                       example: "org_abc123"
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *                     updatedAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Invalid request body or cannot update system role
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Cannot modify system roles"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.update required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
const updateRoleSchema = z.object({
  name: z.string().min(1).optional(),
  description: z.string().optional(),
})

router.patch(
  '/organizations/:organizationId/roles/:roleId',
  requireAuth,
  requirePermission('role.update', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { roleId } = req.params

      // Validate request body
      const validation = updateRoleSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({
          success: false,
          error: validation.error.errors[0].message,
        })
      }

      const { name, description } = validation.data

      const result = await updateRole(roleId, name, description)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error updating role:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/roles/{roleId}:
 *   delete:
 *     summary: Delete a custom role
 *     description: Deletes a custom role from the organization. System roles cannot be deleted. Users with this role will have it removed.
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: string
 *         description: The role ID to delete
 *         example: "role_xyz789"
 *     responses:
 *       200:
 *         description: Role deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       example: "role_xyz789"
 *                     name:
 *                       type: string
 *                       example: "Content Manager"
 *                     deleted:
 *                       type: boolean
 *                       example: true
 *       400:
 *         description: Cannot delete system role
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Cannot delete system roles"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.delete required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
router.delete(
  '/organizations/:organizationId/roles/:roleId',
  requireAuth,
  requirePermission('role.delete', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { roleId } = req.params

      const result = await deleteRole(roleId)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error deleting role:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

// ============================================================================
// Permission Management Endpoints
// ============================================================================

/**
 * @openapi
 * /api/permissions:
 *   get:
 *     summary: Get all available permissions
 *     description: Retrieves all permissions available in the system. Any authenticated user can view this list.
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: Permissions retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         example: "perm_abc123"
 *                       code:
 *                         type: string
 *                         example: "role.read"
 *                       name:
 *                         type: string
 *                         example: "Read Roles"
 *                       description:
 *                         type: string
 *                         example: "View roles and their permissions"
 *                       category:
 *                         type: string
 *                         example: "Roles"
 *                       createdAt:
 *                         type: string
 *                         format: date-time
 *                 count:
 *                   type: integer
 *                   example: 20
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
router.get('/permissions', requireAuth, async (_req, res) => {
  try {
    const result = await getAllPermissions()

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error,
      })
    }

    res.json({
      success: true,
      data: result.data,
      count: result.data?.length || 0,
    })
  } catch (error) {
    console.error('Error fetching permissions:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})

/**
 * @openapi
 * /api/organizations/{organizationId}/roles/{roleId}/permissions:
 *   get:
 *     summary: Get permissions for a role
 *     description: Retrieves all permissions assigned to a specific role
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: string
 *         description: The role ID
 *         example: "role_abc123"
 *     responses:
 *       200:
 *         description: Role permissions retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         example: "perm_abc123"
 *                       code:
 *                         type: string
 *                         example: "lesson.read"
 *                       name:
 *                         type: string
 *                         example: "Read Lessons"
 *                       description:
 *                         type: string
 *                         example: "View lessons and lesson content"
 *                       category:
 *                         type: string
 *                         example: "Lessons"
 *                 count:
 *                   type: integer
 *                   example: 5
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.read required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
router.get(
  '/organizations/:organizationId/roles/:roleId/permissions',
  requireAuth,
  requirePermission('role.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { roleId } = req.params

      const result = await getRolePermissions(roleId)

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
        count: result.data?.length || 0,
      })
    } catch (error) {
      console.error('Error fetching role permissions:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/roles/{roleId}/permissions:
 *   put:
 *     summary: Update role permissions
 *     description: Replaces all permissions for a custom role with the provided list. System roles cannot be modified.
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: string
 *         description: The role ID
 *         example: "role_xyz789"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - permissionIds
 *             properties:
 *               permissionIds:
 *                 type: array
 *                 items:
 *                   type: string
 *                 description: Array of permission IDs to assign to the role
 *                 example: ["perm_abc123", "perm_def456", "perm_ghi789"]
 *     responses:
 *       200:
 *         description: Role permissions updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     roleId:
 *                       type: string
 *                       example: "role_xyz789"
 *                     permissions:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                           code:
 *                             type: string
 *                           name:
 *                             type: string
 *       400:
 *         description: Invalid request body or cannot modify system role
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Cannot modify system roles"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.update required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
const updatePermissionsSchema = z.object({
  permissionIds: z.array(z.string()).min(0, 'Permission IDs must be an array'),
})

router.put(
  '/organizations/:organizationId/roles/:roleId/permissions',
  requireAuth,
  requirePermission('role.update', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { roleId } = req.params

      // Validate request body
      const validation = updatePermissionsSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({
          success: false,
          error: validation.error.errors[0].message,
        })
      }

      const { permissionIds } = validation.data

      const result = await updateRolePermissions(roleId, permissionIds)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error updating role permissions:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

// ============================================================================
// User Role Assignment Endpoints
// ============================================================================

/**
 * @openapi
 * /api/organizations/{organizationId}/users/{userId}/roles:
 *   get:
 *     summary: Get user's roles in an organization
 *     description: Retrieves all roles assigned to a specific user within an organization
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: The user ID
 *         example: "user_abc123"
 *     responses:
 *       200:
 *         description: User roles retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         example: "userrole_abc123"
 *                       roleId:
 *                         type: string
 *                         example: "role_abc123"
 *                       role:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                           name:
 *                             type: string
 *                           description:
 *                             type: string
 *                           isSystem:
 *                             type: boolean
 *                       assignedAt:
 *                         type: string
 *                         format: date-time
 *                       assignedBy:
 *                         type: string
 *                         nullable: true
 *                 count:
 *                   type: integer
 *                   example: 2
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.read required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
router.get(
  '/organizations/:organizationId/users/:userId/roles',
  requireAuth,
  requirePermission('role.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { userId, organizationId } = req.params

      const result = await getUserRoles(userId, organizationId)

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
        count: result.data?.length || 0,
      })
    } catch (error) {
      console.error('Error fetching user roles:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/roles/{roleId}/users:
 *   get:
 *     summary: Get users with a specific role
 *     description: Retrieves all users who have been assigned a specific role in the organization
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: string
 *         description: The role ID
 *         example: "role_abc123"
 *     responses:
 *       200:
 *         description: Users with role retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         example: "userrole_abc123"
 *                       userId:
 *                         type: string
 *                         example: "user_abc123"
 *                       user:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                           name:
 *                             type: string
 *                           email:
 *                             type: string
 *                           picture:
 *                             type: string
 *                             nullable: true
 *                       assignedAt:
 *                         type: string
 *                         format: date-time
 *                       assignedBy:
 *                         type: string
 *                         nullable: true
 *                 count:
 *                   type: integer
 *                   example: 10
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.read required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
router.get(
  '/organizations/:organizationId/roles/:roleId/users',
  requireAuth,
  requirePermission('role.read', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { roleId, organizationId } = req.params

      const result = await getUsersWithRole(roleId, organizationId)

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
        count: result.data?.length || 0,
      })
    } catch (error) {
      console.error('Error fetching users with role:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/users/{userId}/roles:
 *   post:
 *     summary: Assign a role to a user
 *     description: Assigns a role to a user within an organization. The user must be a member of the organization.
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: The user ID to assign the role to
 *         example: "user_abc123"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - roleId
 *             properties:
 *               roleId:
 *                 type: string
 *                 minLength: 1
 *                 description: The ID of the role to assign
 *                 example: "role_abc123"
 *     responses:
 *       201:
 *         description: Role assigned successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       example: "userrole_abc123"
 *                     userId:
 *                       type: string
 *                       example: "user_abc123"
 *                     roleId:
 *                       type: string
 *                       example: "role_abc123"
 *                     organizationId:
 *                       type: string
 *                       example: "org_abc123"
 *                     assignedAt:
 *                       type: string
 *                       format: date-time
 *                     assignedBy:
 *                       type: string
 *                       example: "user_xyz789"
 *       400:
 *         description: Invalid request or user already has role
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "User already has this role"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.assign required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
const assignRoleSchema = z.object({
  roleId: z.string().min(1, 'Role ID is required'),
})

router.post(
  '/organizations/:organizationId/users/:userId/roles',
  requireAuth,
  requirePermission('role.assign', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { userId, organizationId } = req.params
      const assignedBy = (req.user as any)?.id

      // Validate request body
      const validation = assignRoleSchema.safeParse(req.body)
      if (!validation.success) {
        return res.status(400).json({
          success: false,
          error: validation.error.errors[0].message,
        })
      }

      const { roleId } = validation.data

      const result = await assignRole(userId, roleId, organizationId, assignedBy)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.status(201).json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error assigning role:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

/**
 * @openapi
 * /api/organizations/{organizationId}/users/{userId}/roles/{roleId}:
 *   delete:
 *     summary: Remove a role from a user
 *     description: Removes a role assignment from a user within an organization
 *     tags: [Roles]
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: organizationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The organization ID
 *         example: "org_abc123"
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: The user ID
 *         example: "user_abc123"
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: string
 *         description: The role ID to remove
 *         example: "role_abc123"
 *     responses:
 *       200:
 *         description: Role removed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     userId:
 *                       type: string
 *                       example: "user_abc123"
 *                     roleId:
 *                       type: string
 *                       example: "role_abc123"
 *                     removed:
 *                       type: boolean
 *                       example: true
 *       400:
 *         description: User does not have this role
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "User does not have this role"
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Authentication required"
 *       403:
 *         description: Missing required permission
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Permission denied: role.assign required"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 error:
 *                   type: string
 *                   example: "Internal server error"
 */
router.delete(
  '/organizations/:organizationId/users/:userId/roles/:roleId',
  requireAuth,
  requirePermission('role.assign', 'organization', (req) => req.params.organizationId),
  async (req, res) => {
    try {
      const { userId, roleId, organizationId } = req.params

      const result = await removeRole(userId, roleId, organizationId)

      if (!result.success) {
        return res.status(400).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
      })
    } catch (error) {
      console.error('Error removing role:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
)

export default router
