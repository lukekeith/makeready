/**
 * API Keys Routes
 *
 * CRUD endpoints for managing API keys.
 * Requires session authentication (cannot create/manage API keys using an API key).
 */

/**
 * @openapi
 * components:
 *   schemas:
 *     ApiKey:
 *       type: object
 *       description: API key object (returned for list/get operations)
 *       properties:
 *         id:
 *           type: string
 *           description: Unique identifier for the API key
 *           example: "clx1234567890abcdef"
 *         keyPrefix:
 *           type: string
 *           description: First 8 characters of the key for identification
 *           example: "mr_abc12"
 *         name:
 *           type: string
 *           description: User-friendly name for the API key
 *           example: "Production App Key"
 *         description:
 *           type: string
 *           nullable: true
 *           description: Optional description of the key's purpose
 *           example: "Used for the production mobile app"
 *         isActive:
 *           type: boolean
 *           description: Whether the key is currently active
 *           example: true
 *         expiresAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *           description: Expiration date of the key (null if never expires)
 *           example: "2025-12-31T23:59:59.000Z"
 *         lastUsedAt:
 *           type: string
 *           format: date-time
 *           nullable: true
 *           description: When the key was last used for authentication
 *           example: "2024-06-15T10:30:00.000Z"
 *         usageCount:
 *           type: integer
 *           description: Number of times the key has been used
 *           example: 150
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: When the key was created
 *           example: "2024-01-15T08:00:00.000Z"
 *         updatedAt:
 *           type: string
 *           format: date-time
 *           description: When the key was last updated
 *           example: "2024-06-15T10:30:00.000Z"
 *       required:
 *         - id
 *         - keyPrefix
 *         - name
 *         - isActive
 *         - usageCount
 *         - createdAt
 *         - updatedAt
 *
 *     ApiKeyWithFullKey:
 *       type: object
 *       description: API key object with the full key (only returned on creation)
 *       allOf:
 *         - $ref: '#/components/schemas/ApiKey'
 *         - type: object
 *           properties:
 *             key:
 *               type: string
 *               description: "The full API key. IMPORTANT: This is only shown once at creation time. Store it securely!"
 *               example: "mr_abc123xyz789def456ghi012jkl345mno678pqr901stu234vwx567yz"
 *           required:
 *             - key
 *
 *     CreateApiKeyRequest:
 *       type: object
 *       description: Request body for creating a new API key
 *       properties:
 *         name:
 *           type: string
 *           minLength: 1
 *           maxLength: 100
 *           description: User-friendly name for the API key
 *           example: "Production App Key"
 *         description:
 *           type: string
 *           maxLength: 500
 *           description: Optional description of the key's purpose
 *           example: "Used for the production mobile app"
 *         expiresAt:
 *           type: string
 *           format: date-time
 *           description: Optional expiration date for the key
 *           example: "2025-12-31T23:59:59.000Z"
 *       required:
 *         - name
 *
 *     UpdateApiKeyRequest:
 *       type: object
 *       description: Request body for updating an API key
 *       properties:
 *         name:
 *           type: string
 *           minLength: 1
 *           maxLength: 100
 *           description: Updated name for the API key
 *           example: "Updated Key Name"
 *         description:
 *           type: string
 *           maxLength: 500
 *           nullable: true
 *           description: Updated description (set to null to clear)
 *           example: "Updated description"
 *         isActive:
 *           type: boolean
 *           description: Set to false to revoke the key
 *           example: false
 *
 *     ApiKeyListResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: true
 *         apiKeys:
 *           type: array
 *           items:
 *             $ref: '#/components/schemas/ApiKey'
 *
 *     ApiKeyResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: true
 *         apiKey:
 *           $ref: '#/components/schemas/ApiKey'
 *
 *     ApiKeyCreatedResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: true
 *         message:
 *           type: string
 *           example: "API key created. Save this key - it will not be shown again!"
 *         apiKey:
 *           $ref: '#/components/schemas/ApiKeyWithFullKey'
 *
 *     ApiKeyUpdatedResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: true
 *         message:
 *           type: string
 *           example: "API key updated"
 *         apiKey:
 *           $ref: '#/components/schemas/ApiKey'
 *
 *     ApiKeyDeletedResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: true
 *         message:
 *           type: string
 *           example: "API key deleted"
 *
 *     ApiKeyErrorResponse:
 *       type: object
 *       properties:
 *         success:
 *           type: boolean
 *           example: false
 *         error:
 *           type: string
 *           example: "Error message"
 *         details:
 *           type: array
 *           description: Validation error details (only for 400 errors)
 *           items:
 *             type: object
 *             properties:
 *               code:
 *                 type: string
 *               message:
 *                 type: string
 *               path:
 *                 type: array
 *                 items:
 *                   type: string
 */

import { Router, Request, Response, NextFunction } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import {
  generateApiKey,
  hashApiKey,
  getKeyPrefix,
} from '../lib/api-key.js'

const router = Router()

// ============================================================================
// Validation Schemas
// ============================================================================

const createApiKeySchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  expiresAt: z.string().datetime().optional(),
})

const updateApiKeySchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().max(500).optional().nullable(),
  isActive: z.boolean().optional(),
})

// ============================================================================
// Helper to check session-only auth (no API key auth allowed)
// ============================================================================

function requireSessionAuth(
  req: Request,
  res: Response,
  next: NextFunction
) {
  // If request was authenticated via API key, reject it
  if (req.apiKeyId) {
    return res.status(403).json({
      success: false,
      error: 'API key management requires session authentication. Please use the web interface.',
    })
  }

  // Verify session auth
  if (!req.isAuthenticated || !req.isAuthenticated()) {
    return res.status(401).json({
      success: false,
      error: 'Session authentication required',
    })
  }

  next()
}

// ============================================================================
// POST /api/api-keys - Create a new API key
// ============================================================================

/**
 * @openapi
 * /api/api-keys:
 *   post:
 *     tags:
 *       - API Keys
 *     summary: Create a new API key
 *     description: |
 *       Creates a new API key for the authenticated user.
 *
 *       **IMPORTANT:** The full API key is only returned once in the response.
 *       Store it securely - it cannot be retrieved again!
 *
 *       Requires session authentication (cookie-based). API key authentication
 *       cannot be used to create or manage API keys.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/CreateApiKeyRequest'
 *           examples:
 *             basic:
 *               summary: Basic key creation
 *               value:
 *                 name: "My API Key"
 *             withDescription:
 *               summary: With description
 *               value:
 *                 name: "Production Key"
 *                 description: "Used for production mobile app"
 *             withExpiry:
 *               summary: With expiration date
 *               value:
 *                 name: "Temporary Key"
 *                 description: "Expires end of year"
 *                 expiresAt: "2025-12-31T23:59:59.000Z"
 *     responses:
 *       201:
 *         description: API key created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyCreatedResponse'
 *             example:
 *               success: true
 *               message: "API key created. Save this key - it will not be shown again!"
 *               apiKey:
 *                 id: "clx1234567890abcdef"
 *                 keyPrefix: "mr_abc12"
 *                 name: "Production Key"
 *                 description: "Used for production mobile app"
 *                 isActive: true
 *                 expiresAt: null
 *                 createdAt: "2024-06-15T10:00:00.000Z"
 *                 key: "mr_abc123xyz789def456ghi012jkl345mno678pqr901stu234vwx567yz"
 *       400:
 *         description: Invalid request body
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Invalid request body"
 *               details:
 *                 - code: "too_small"
 *                   message: "String must contain at least 1 character(s)"
 *                   path: ["name"]
 *       401:
 *         description: Not authenticated or user not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Session authentication required"
 *       403:
 *         description: API key authentication not allowed for this endpoint
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "API key management requires session authentication. Please use the web interface."
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to create API key"
 */
router.post('/', requireAuth, requireSessionAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not found',
      })
    }

    // Validate request body
    const validation = createApiKeySchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validation.error.issues,
      })
    }

    const { name, description, expiresAt } = validation.data

    // Generate the API key
    const fullKey = generateApiKey()
    const keyHash = hashApiKey(fullKey)
    const keyPrefix = getKeyPrefix(fullKey)

    // Create the API key record
    const apiKey = await prisma.apiKey.create({
      data: {
        keyHash,
        keyPrefix,
        name,
        description,
        userId,
        expiresAt: expiresAt ? new Date(expiresAt) : null,
      },
      select: {
        id: true,
        keyPrefix: true,
        name: true,
        description: true,
        isActive: true,
        expiresAt: true,
        createdAt: true,
      },
    })

    // Return the full key ONLY on creation
    // This is the only time the full key is returned!
    res.status(201).json({
      success: true,
      message: 'API key created. Save this key - it will not be shown again!',
      apiKey: {
        ...apiKey,
        key: fullKey, // Full key returned ONLY on creation
      },
    })
  } catch (error) {
    console.error('Error creating API key:', error)
    return res.status(500).json({
      success: false,
      error: 'Failed to create API key',
    })
  }
})

// ============================================================================
// GET /api/api-keys - List user's API keys
// ============================================================================

/**
 * @openapi
 * /api/api-keys:
 *   get:
 *     tags:
 *       - API Keys
 *     summary: List all API keys
 *     description: |
 *       Returns a list of all API keys belonging to the authenticated user.
 *
 *       Keys are returned in descending order by creation date (newest first).
 *       The full key value is never returned - only the key prefix for identification.
 *
 *       Requires session authentication (cookie-based).
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: List of API keys
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyListResponse'
 *             example:
 *               success: true
 *               apiKeys:
 *                 - id: "clx1234567890abcdef"
 *                   keyPrefix: "mr_abc12"
 *                   name: "Production Key"
 *                   description: "Used for production mobile app"
 *                   isActive: true
 *                   expiresAt: null
 *                   lastUsedAt: "2024-06-15T10:30:00.000Z"
 *                   usageCount: 150
 *                   createdAt: "2024-01-15T08:00:00.000Z"
 *                   updatedAt: "2024-06-15T10:30:00.000Z"
 *                 - id: "clx9876543210fedcba"
 *                   keyPrefix: "mr_xyz98"
 *                   name: "Development Key"
 *                   description: null
 *                   isActive: false
 *                   expiresAt: "2024-12-31T23:59:59.000Z"
 *                   lastUsedAt: "2024-03-01T14:22:00.000Z"
 *                   usageCount: 42
 *                   createdAt: "2024-02-01T12:00:00.000Z"
 *                   updatedAt: "2024-05-01T09:00:00.000Z"
 *       401:
 *         description: Not authenticated or user not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Session authentication required"
 *       403:
 *         description: API key authentication not allowed for this endpoint
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "API key management requires session authentication. Please use the web interface."
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to list API keys"
 */
router.get('/', requireAuth, requireSessionAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not found',
      })
    }

    const apiKeys = await prisma.apiKey.findMany({
      where: { userId },
      select: {
        id: true,
        keyPrefix: true,
        name: true,
        description: true,
        isActive: true,
        expiresAt: true,
        lastUsedAt: true,
        usageCount: true,
        createdAt: true,
        updatedAt: true,
      },
      orderBy: { createdAt: 'desc' },
    })

    res.json({
      success: true,
      apiKeys,
    })
  } catch (error) {
    console.error('Error listing API keys:', error)
    return res.status(500).json({
      success: false,
      error: 'Failed to list API keys',
    })
  }
})

// ============================================================================
// GET /api/api-keys/:id - Get a specific API key
// ============================================================================

/**
 * @openapi
 * /api/api-keys/{id}:
 *   get:
 *     tags:
 *       - API Keys
 *     summary: Get a specific API key
 *     description: |
 *       Returns details of a specific API key by ID.
 *
 *       The full key value is never returned - only the key prefix for identification.
 *       Users can only access their own API keys.
 *
 *       Requires session authentication (cookie-based).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: The unique identifier of the API key
 *         schema:
 *           type: string
 *         example: "clx1234567890abcdef"
 *     responses:
 *       200:
 *         description: API key details
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyResponse'
 *             example:
 *               success: true
 *               apiKey:
 *                 id: "clx1234567890abcdef"
 *                 keyPrefix: "mr_abc12"
 *                 name: "Production Key"
 *                 description: "Used for production mobile app"
 *                 isActive: true
 *                 expiresAt: null
 *                 lastUsedAt: "2024-06-15T10:30:00.000Z"
 *                 usageCount: 150
 *                 createdAt: "2024-01-15T08:00:00.000Z"
 *                 updatedAt: "2024-06-15T10:30:00.000Z"
 *       401:
 *         description: Not authenticated or user not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Session authentication required"
 *       403:
 *         description: API key authentication not allowed for this endpoint
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "API key management requires session authentication. Please use the web interface."
 *       404:
 *         description: API key not found or not owned by user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "API key not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to get API key"
 */
router.get('/:id', requireAuth, requireSessionAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    const { id } = req.params

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not found',
      })
    }

    const apiKey = await prisma.apiKey.findFirst({
      where: {
        id,
        userId, // Ensure user owns this key
      },
      select: {
        id: true,
        keyPrefix: true,
        name: true,
        description: true,
        isActive: true,
        expiresAt: true,
        lastUsedAt: true,
        usageCount: true,
        createdAt: true,
        updatedAt: true,
      },
    })

    if (!apiKey) {
      return res.status(404).json({
        success: false,
        error: 'API key not found',
      })
    }

    res.json({
      success: true,
      apiKey,
    })
  } catch (error) {
    console.error('Error getting API key:', error)
    return res.status(500).json({
      success: false,
      error: 'Failed to get API key',
    })
  }
})

// ============================================================================
// PATCH /api/api-keys/:id - Update an API key
// ============================================================================

/**
 * @openapi
 * /api/api-keys/{id}:
 *   patch:
 *     tags:
 *       - API Keys
 *     summary: Update an API key
 *     description: |
 *       Updates an existing API key's metadata or status.
 *
 *       You can update the name, description, or active status. Setting `isActive`
 *       to `false` effectively revokes the key without deleting it.
 *
 *       Users can only update their own API keys.
 *
 *       Requires session authentication (cookie-based).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: The unique identifier of the API key
 *         schema:
 *           type: string
 *         example: "clx1234567890abcdef"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UpdateApiKeyRequest'
 *           examples:
 *             updateName:
 *               summary: Update name
 *               value:
 *                 name: "Renamed API Key"
 *             revokeKey:
 *               summary: Revoke key
 *               value:
 *                 isActive: false
 *             updateMultiple:
 *               summary: Update multiple fields
 *               value:
 *                 name: "Updated Key"
 *                 description: "Updated description"
 *             clearDescription:
 *               summary: Clear description
 *               value:
 *                 description: null
 *     responses:
 *       200:
 *         description: API key updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyUpdatedResponse'
 *             examples:
 *               updated:
 *                 summary: Key updated
 *                 value:
 *                   success: true
 *                   message: "API key updated"
 *                   apiKey:
 *                     id: "clx1234567890abcdef"
 *                     keyPrefix: "mr_abc12"
 *                     name: "Updated Key"
 *                     description: "Updated description"
 *                     isActive: true
 *                     expiresAt: null
 *                     lastUsedAt: "2024-06-15T10:30:00.000Z"
 *                     usageCount: 150
 *                     createdAt: "2024-01-15T08:00:00.000Z"
 *                     updatedAt: "2024-06-16T09:00:00.000Z"
 *               revoked:
 *                 summary: Key revoked
 *                 value:
 *                   success: true
 *                   message: "API key revoked"
 *                   apiKey:
 *                     id: "clx1234567890abcdef"
 *                     keyPrefix: "mr_abc12"
 *                     name: "Production Key"
 *                     description: "Used for production mobile app"
 *                     isActive: false
 *                     expiresAt: null
 *                     lastUsedAt: "2024-06-15T10:30:00.000Z"
 *                     usageCount: 150
 *                     createdAt: "2024-01-15T08:00:00.000Z"
 *                     updatedAt: "2024-06-16T09:00:00.000Z"
 *       400:
 *         description: Invalid request body
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Invalid request body"
 *               details:
 *                 - code: "too_big"
 *                   message: "String must contain at most 100 character(s)"
 *                   path: ["name"]
 *       401:
 *         description: Not authenticated or user not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Session authentication required"
 *       403:
 *         description: API key authentication not allowed for this endpoint
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "API key management requires session authentication. Please use the web interface."
 *       404:
 *         description: API key not found or not owned by user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "API key not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to update API key"
 */
router.patch('/:id', requireAuth, requireSessionAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    const { id } = req.params

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not found',
      })
    }

    // Validate request body
    const validation = updateApiKeySchema.safeParse(req.body)
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validation.error.issues,
      })
    }

    // Check that user owns this key
    const existing = await prisma.apiKey.findFirst({
      where: { id, userId },
    })

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: 'API key not found',
      })
    }

    const { name, description, isActive } = validation.data

    const apiKey = await prisma.apiKey.update({
      where: { id },
      data: {
        ...(name !== undefined && { name }),
        ...(description !== undefined && { description }),
        ...(isActive !== undefined && { isActive }),
      },
      select: {
        id: true,
        keyPrefix: true,
        name: true,
        description: true,
        isActive: true,
        expiresAt: true,
        lastUsedAt: true,
        usageCount: true,
        createdAt: true,
        updatedAt: true,
      },
    })

    res.json({
      success: true,
      message: isActive === false ? 'API key revoked' : 'API key updated',
      apiKey,
    })
  } catch (error) {
    console.error('Error updating API key:', error)
    return res.status(500).json({
      success: false,
      error: 'Failed to update API key',
    })
  }
})

// ============================================================================
// DELETE /api/api-keys/:id - Delete an API key
// ============================================================================

/**
 * @openapi
 * /api/api-keys/{id}:
 *   delete:
 *     tags:
 *       - API Keys
 *     summary: Delete an API key
 *     description: |
 *       Permanently deletes an API key.
 *
 *       This action cannot be undone. If you want to temporarily disable a key
 *       without deleting it, use the PATCH endpoint to set `isActive` to `false`.
 *
 *       Users can only delete their own API keys.
 *
 *       Requires session authentication (cookie-based).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: The unique identifier of the API key to delete
 *         schema:
 *           type: string
 *         example: "clx1234567890abcdef"
 *     responses:
 *       200:
 *         description: API key deleted successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyDeletedResponse'
 *             example:
 *               success: true
 *               message: "API key deleted"
 *       401:
 *         description: Not authenticated or user not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Session authentication required"
 *       403:
 *         description: API key authentication not allowed for this endpoint
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "API key management requires session authentication. Please use the web interface."
 *       404:
 *         description: API key not found or not owned by user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "API key not found"
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ApiKeyErrorResponse'
 *             example:
 *               success: false
 *               error: "Failed to delete API key"
 */
router.delete('/:id', requireAuth, requireSessionAuth, async (req, res) => {
  try {
    const userId = (req.user as any)?.id
    const { id } = req.params

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'User not found',
      })
    }

    // Check that user owns this key
    const existing = await prisma.apiKey.findFirst({
      where: { id, userId },
    })

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: 'API key not found',
      })
    }

    await prisma.apiKey.delete({
      where: { id },
    })

    res.json({
      success: true,
      message: 'API key deleted',
    })
  } catch (error) {
    console.error('Error deleting API key:', error)
    return res.status(500).json({
      success: false,
      error: 'Failed to delete API key',
    })
  }
})

export default router
