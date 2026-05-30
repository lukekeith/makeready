import { Router, Request } from 'express'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { requireAuth } from '../middleware/auth.js'
import { trackActivity } from '../services/activity.js'

const router = Router()

/**
 * Extract userId from the authenticated request.
 * Supports Google OAuth (req.user), API keys (req.user), and member sessions (req.session.memberId).
 */
async function getUserId(req: Request): Promise<string | null> {
  // Google OAuth or API key auth
  if (req.user && (req.user as any).id) {
    return (req.user as any).id
  }

  // Member session — look up linked userId
  if (req.session.memberId) {
    const member = await prisma.member.findUnique({
      where: { id: req.session.memberId },
      select: { userId: true },
    })
    return member?.userId ?? null
  }

  return null
}

// ============================================================================
// Lesson Template CRUD
// ============================================================================

/**
 * @openapi
 * /api/templates:
 *   get:
 *     summary: List lesson templates
 *     description: Returns system templates and the current user's own templates
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     responses:
 *       200:
 *         description: List of templates
 */
router.get('/templates', requireAuth, async (req, res) => {
  try {
    const userId = await getUserId(req)

    const templates = await prisma.lessonTemplate.findMany({
      where: {
        isActive: true,
        OR: [
          { isSystem: true },
          ...(userId ? [{ creatorId: userId }] : []),
        ],
      },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
        },
      },
      orderBy: [
        { isSystem: 'desc' },
        { name: 'asc' },
      ],
    })

    res.json({ templates })
  } catch (error) {
    console.error('Error listing templates:', error)
    res.status(500).json({ error: 'Failed to list templates' })
  }
})

/**
 * @openapi
 * /api/templates/{id}:
 *   get:
 *     summary: Get a template with its activities
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Template details
 */
router.get('/templates/:id', requireAuth, async (req, res) => {
  try {
    const template = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
        },
        creator: {
          select: { id: true, name: true },
        },
      },
    })

    if (!template) {
      return res.status(404).json({ error: 'Template not found' })
    }

    res.json({ template })
  } catch (error) {
    console.error('Error fetching template:', error)
    res.status(500).json({ error: 'Failed to fetch template' })
  }
})

const createTemplateSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).nullable().optional(),
  activities: z.array(z.object({
    type: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']),
    orderNumber: z.number().int().positive(),
    title: z.string().min(1).max(100),
    referenceTitle: z.string().max(200).nullable().optional(),
    helpTitle: z.string().max(200).nullable().optional(),
    helpDescription: z.string().max(1000).nullable().optional(),
    helpAlwaysVisible: z.boolean().optional().default(false),
  })).min(1),
})

/**
 * @openapi
 * /api/templates:
 *   post:
 *     summary: Create a new lesson template
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, activities]
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               activities:
 *                 type: array
 *     responses:
 *       201:
 *         description: Template created
 */
router.post('/templates', requireAuth, async (req, res) => {
  try {
    const data = createTemplateSchema.parse(req.body)
    const userId = await getUserId(req)

    if (!userId) {
      return res.status(400).json({ error: 'User account required to create templates' })
    }

    // Look up creator's organization
    const creatorOrg = await prisma.organization.findFirst({
      where: { ownerId: userId },
      select: { id: true },
    })

    const template = await prisma.lessonTemplate.create({
      data: {
        name: data.name,
        description: data.description ?? null,
        isSystem: false,
        creatorId: userId,
        organizationId: creatorOrg?.id,
        activities: {
          create: data.activities.map((a) => ({
            type: a.type,
            orderNumber: a.orderNumber,
            title: a.title,
            referenceTitle: a.referenceTitle ?? null,
            helpTitle: a.helpTitle ?? null,
            helpDescription: a.helpDescription ?? null,
            helpAlwaysVisible: a.helpAlwaysVisible ?? false,
          })),
        },
      },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
        },
      },
    })

    trackActivity({
      actorId: userId,
      action: 'CREATED',
      resourceType: 'TEMPLATE',
      resourceId: template.id,
      resourceName: template.name,
      organizationId: creatorOrg?.id,
    })

    res.status(201).json({ template })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid request', details: error.errors })
    }
    console.error('Error creating template:', error)
    res.status(500).json({ error: 'Failed to create template' })
  }
})

const updateTemplateSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().max(500).nullable().optional(),
})

/**
 * @openapi
 * /api/templates/{id}:
 *   patch:
 *     summary: Update a template (creator only)
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Template updated
 */
router.patch('/templates/:id', requireAuth, async (req, res) => {
  try {
    const data = updateTemplateSchema.parse(req.body)
    const userId = await getUserId(req)

    const template = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
    })

    if (!template) {
      return res.status(404).json({ error: 'Template not found' })
    }

    if (template.isSystem || template.creatorId !== userId) {
      return res.status(403).json({ error: 'Cannot edit this template' })
    }

    const updated = await prisma.lessonTemplate.update({
      where: { id: req.params.id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.description !== undefined && { description: data.description }),
        updatedById: userId,
      },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
        },
      },
    })

    trackActivity({
      actorId: userId!,
      action: 'UPDATED',
      resourceType: 'TEMPLATE',
      resourceId: updated.id,
      resourceName: updated.name,
      organizationId: updated.organizationId,
    })

    res.json({ template: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid request', details: error.errors })
    }
    console.error('Error updating template:', error)
    res.status(500).json({ error: 'Failed to update template' })
  }
})

/**
 * @openapi
 * /api/templates/{id}:
 *   delete:
 *     summary: Soft delete a template (creator only)
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Template deleted
 */
router.delete('/templates/:id', requireAuth, async (req, res) => {
  try {
    const userId = await getUserId(req)

    const template = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
    })

    if (!template) {
      return res.status(404).json({ error: 'Template not found' })
    }

    if (template.isSystem || template.creatorId !== userId) {
      return res.status(403).json({ error: 'Cannot delete this template' })
    }

    await prisma.lessonTemplate.update({
      where: { id: req.params.id },
      data: { isActive: false },
    })

    res.json({ success: true, message: 'Template deleted' })
  } catch (error) {
    console.error('Error deleting template:', error)
    res.status(500).json({ error: 'Failed to delete template' })
  }
})

/**
 * @openapi
 * /api/templates/{id}/duplicate:
 *   post:
 *     summary: Duplicate a template as the user's own
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       201:
 *         description: Template duplicated
 */
router.post('/templates/:id/duplicate', requireAuth, async (req, res) => {
  try {
    const userId = await getUserId(req)

    if (!userId) {
      return res.status(400).json({ error: 'User account required' })
    }

    const source = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
        },
      },
    })

    if (!source) {
      return res.status(404).json({ error: 'Template not found' })
    }

    const name = req.body.name || `${source.name} (Copy)`

    const duplicate = await prisma.lessonTemplate.create({
      data: {
        name,
        description: source.description,
        isSystem: false,
        creatorId: userId,
        sourceTemplateId: source.id,
        activities: {
          create: source.activities.map((a) => ({
            type: a.type,
            orderNumber: a.orderNumber,
            title: a.title,
            referenceTitle: a.referenceTitle,
            helpTitle: a.helpTitle,
            helpDescription: a.helpDescription,
            helpAlwaysVisible: a.helpAlwaysVisible,
            helpIcon: a.helpIcon,
          })),
        },
      },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
        },
      },
    })

    res.status(201).json({ template: duplicate })
  } catch (error) {
    console.error('Error duplicating template:', error)
    res.status(500).json({ error: 'Failed to duplicate template' })
  }
})

// ============================================================================
// Template Activity Management
// ============================================================================

const addActivitySchema = z.object({
  type: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']),
  orderNumber: z.number().int().positive(),
  title: z.string().min(1).max(100),
  referenceTitle: z.string().max(200).nullable().optional(),
  helpTitle: z.string().max(200).nullable().optional(),
  helpDescription: z.string().max(1000).nullable().optional(),
  helpAlwaysVisible: z.boolean().optional().default(false),
})

/**
 * @openapi
 * /api/templates/{id}/activities:
 *   post:
 *     summary: Add an activity to a template
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       201:
 *         description: Activity added
 */
router.post('/templates/:id/activities', requireAuth, async (req, res) => {
  try {
    const data = addActivitySchema.parse(req.body)
    const userId = await getUserId(req)

    const template = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
    })

    if (!template) {
      return res.status(404).json({ error: 'Template not found' })
    }

    if (template.isSystem || template.creatorId !== userId) {
      return res.status(403).json({ error: 'Cannot modify this template' })
    }

    // Shift existing activities down to make room
    await prisma.lessonTemplateActivity.updateMany({
      where: {
        templateId: req.params.id,
        orderNumber: { gte: data.orderNumber },
      },
      data: {
        orderNumber: { increment: 1 },
      },
    })

    const activity = await prisma.lessonTemplateActivity.create({
      data: {
        templateId: req.params.id,
        type: data.type,
        orderNumber: data.orderNumber,
        title: data.title,
        referenceTitle: data.referenceTitle ?? null,
        helpTitle: data.helpTitle ?? null,
        helpDescription: data.helpDescription ?? null,
        helpAlwaysVisible: data.helpAlwaysVisible ?? false,
      },
    })

    res.status(201).json({ activity })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid request', details: error.errors })
    }
    console.error('Error adding activity:', error)
    res.status(500).json({ error: 'Failed to add activity' })
  }
})

const updateActivitySchema = z.object({
  type: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']).optional(),
  title: z.string().min(1).max(100).optional(),
  referenceTitle: z.string().max(200).nullable().optional(),
  helpTitle: z.string().max(200).nullable().optional(),
  helpDescription: z.string().max(1000).nullable().optional(),
  helpAlwaysVisible: z.boolean().optional(),
})

/**
 * @openapi
 * /api/templates/{id}/activities/{activityId}:
 *   patch:
 *     summary: Update a template activity
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Activity updated
 */
router.patch('/templates/:id/activities/:activityId', requireAuth, async (req, res) => {
  try {
    const data = updateActivitySchema.parse(req.body)
    const userId = await getUserId(req)

    const template = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
    })

    if (!template) {
      return res.status(404).json({ error: 'Template not found' })
    }

    if (template.isSystem || template.creatorId !== userId) {
      return res.status(403).json({ error: 'Cannot modify this template' })
    }

    const activity = await prisma.lessonTemplateActivity.findFirst({
      where: {
        id: req.params.activityId,
        templateId: req.params.id,
      },
    })

    if (!activity) {
      return res.status(404).json({ error: 'Activity not found' })
    }

    const updated = await prisma.lessonTemplateActivity.update({
      where: { id: req.params.activityId },
      data: {
        ...(data.type !== undefined && { type: data.type }),
        ...(data.title !== undefined && { title: data.title }),
        ...(data.referenceTitle !== undefined && { referenceTitle: data.referenceTitle }),
        ...(data.helpTitle !== undefined && { helpTitle: data.helpTitle }),
        ...(data.helpDescription !== undefined && { helpDescription: data.helpDescription }),
        ...(data.helpAlwaysVisible !== undefined && { helpAlwaysVisible: data.helpAlwaysVisible }),
      },
    })

    res.json({ activity: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid request', details: error.errors })
    }
    console.error('Error updating activity:', error)
    res.status(500).json({ error: 'Failed to update activity' })
  }
})

/**
 * @openapi
 * /api/templates/{id}/activities/{activityId}:
 *   delete:
 *     summary: Remove an activity from a template
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Activity removed
 */
router.delete('/templates/:id/activities/:activityId', requireAuth, async (req, res) => {
  try {
    const userId = await getUserId(req)

    const template = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
    })

    if (!template) {
      return res.status(404).json({ error: 'Template not found' })
    }

    if (template.isSystem || template.creatorId !== userId) {
      return res.status(403).json({ error: 'Cannot modify this template' })
    }

    const activity = await prisma.lessonTemplateActivity.findFirst({
      where: {
        id: req.params.activityId,
        templateId: req.params.id,
      },
    })

    if (!activity) {
      return res.status(404).json({ error: 'Activity not found' })
    }

    // Delete the activity and reorder remaining
    await prisma.$transaction(async (tx) => {
      await tx.lessonTemplateActivity.delete({
        where: { id: req.params.activityId },
      })

      // Reorder remaining activities to be sequential
      const remaining = await tx.lessonTemplateActivity.findMany({
        where: { templateId: req.params.id },
        orderBy: { orderNumber: 'asc' },
      })

      for (let i = 0; i < remaining.length; i++) {
        if (remaining[i].orderNumber !== i + 1) {
          await tx.lessonTemplateActivity.update({
            where: { id: remaining[i].id },
            data: { orderNumber: i + 1 },
          })
        }
      }
    })

    res.json({ success: true, message: 'Activity removed' })
  } catch (error) {
    console.error('Error removing activity:', error)
    res.status(500).json({ error: 'Failed to remove activity' })
  }
})

const reorderSchema = z.object({
  activityIds: z.array(z.string().uuid()).min(1),
})

/**
 * @openapi
 * /api/templates/{id}/reorder-activities:
 *   post:
 *     summary: Reorder template activities
 *     tags: [Templates]
 *     security:
 *       - session: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [activityIds]
 *             properties:
 *               activityIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: Activities reordered
 */
router.post('/templates/:id/reorder-activities', requireAuth, async (req, res) => {
  try {
    const data = reorderSchema.parse(req.body)
    const userId = await getUserId(req)

    const template = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
      include: { activities: true },
    })

    if (!template) {
      return res.status(404).json({ error: 'Template not found' })
    }

    if (template.isSystem || template.creatorId !== userId) {
      return res.status(403).json({ error: 'Cannot modify this template' })
    }

    // Verify all activity IDs belong to this template
    const templateActivityIds = new Set(template.activities.map((a) => a.id))
    for (const id of data.activityIds) {
      if (!templateActivityIds.has(id)) {
        return res.status(400).json({ error: `Activity ${id} does not belong to this template` })
      }
    }

    if (data.activityIds.length !== template.activities.length) {
      return res.status(400).json({ error: 'Must include all activity IDs' })
    }

    // Use a transaction to temporarily set high order numbers, then reassign
    await prisma.$transaction(async (tx) => {
      // First, set all to high numbers to avoid unique constraint conflicts
      for (let i = 0; i < data.activityIds.length; i++) {
        await tx.lessonTemplateActivity.update({
          where: { id: data.activityIds[i] },
          data: { orderNumber: 1000 + i },
        })
      }

      // Then set the correct order
      for (let i = 0; i < data.activityIds.length; i++) {
        await tx.lessonTemplateActivity.update({
          where: { id: data.activityIds[i] },
          data: { orderNumber: i + 1 },
        })
      }
    })

    const updated = await prisma.lessonTemplate.findUnique({
      where: { id: req.params.id },
      include: {
        activities: {
          orderBy: { orderNumber: 'asc' },
        },
      },
    })

    if (userId) {
      trackActivity({
        actorId: userId,
        action: 'UPDATED',
        resourceType: 'TEMPLATE',
        resourceId: req.params.id,
        resourceName: template.name,
        organizationId: template.organizationId ?? undefined,
        metadata: { reordered: 'activities' },
      })
    }

    res.json({ template: updated })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Invalid request', details: error.errors })
    }
    console.error('Error reordering activities:', error)
    res.status(500).json({ error: 'Failed to reorder activities' })
  }
})

export default router
