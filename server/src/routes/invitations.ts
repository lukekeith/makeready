import { Router } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import { getInvitationFeed, getInvitationDetail, InvitationReadError } from '../services/invitation.js'

const router = Router()
const uuid = z.string().uuid().transform(value => value.toLowerCase())
const feedQuery = z.object({
  orgId: uuid.optional(), groupId: uuid.optional(), leaderId: uuid.optional(),
  status: z.enum(['sent','requested','accepted','rejected','expired']).optional(),
  limit: z.string().regex(/^[1-9]\d*$/).transform(Number).pipe(z.number().int().min(1).max(200)).optional(),
}).strict()

/**
 * @openapi
 * components:
 *   schemas:
 *     InvitationFeedItem:
 *       type: object
 *       additionalProperties: false
 *       required: [id, kind, status, recipientPhone, recipientName, memberId, groupId, groupName, organizationId, inviterId, inviterName, date, createdAt]
 *       properties:
 *         id: { type: string, format: uuid }
 *         kind: { type: string, enum: [invite, request] }
 *         status: { type: string, enum: [sent, requested, accepted, rejected, expired] }
 *         recipientPhone: { type: string, nullable: true }
 *         recipientName: { type: string, nullable: true }
 *         memberId: { type: string, nullable: true }
 *         groupId: { type: string, nullable: true }
 *         groupName: { type: string, nullable: true }
 *         organizationId: { type: string, format: uuid }
 *         inviterId: { type: string, nullable: true }
 *         inviterName: { type: string, nullable: true }
 *         date: { type: string, format: date-time }
 *         createdAt: { type: string, format: date-time }
 *     InvitationFeed:
 *       type: object
 *       additionalProperties: false
 *       required: [items, total, filters]
 *       properties:
 *         items: { type: array, items: { $ref: '#/components/schemas/InvitationFeedItem' } }
 *         total: { type: integer, minimum: 0 }
 *         filters:
 *           type: object
 *           required: [orgs, groups, leaders]
 *           properties:
 *             orgs:
 *               type: array
 *               items: { type: object, required: [id, name], properties: { id: { type: string }, name: { type: string } } }
 *             groups:
 *               type: array
 *               items: { type: object, required: [id, name, organizationId], properties: { id: { type: string }, name: { type: string }, organizationId: { type: string } } }
 *             leaders:
 *               type: array
 *               items: { type: object, required: [id, name], properties: { id: { type: string }, name: { type: string } } }
 *     InvitationDetail:
 *       type: object
 *       additionalProperties: false
 *       required: [id, kind, status, recipientPhone, recipientName, inviterName, message, createdAt, member, invitations, events, canResend, canWithdraw]
 *       properties:
 *         id: { type: string, format: uuid }
 *         kind: { type: string, enum: [invite, request] }
 *         status: { type: string, enum: [sent, requested, accepted, rejected, expired, withdrawn] }
 *         recipientPhone: { type: string, nullable: true }
 *         recipientName: { type: string, nullable: true }
 *         inviterName: { type: string, nullable: true }
 *         message: { type: string, nullable: true }
 *         createdAt: { type: string, format: date-time }
 *         member:
 *           type: object
 *           nullable: true
 *           required: [id, name, picture, age, role, birthday, joinedAt]
 *           properties:
 *             id: { type: string }
 *             name: { type: string }
 *             picture: { type: string, nullable: true }
 *             age: { type: integer, nullable: true }
 *             role: { type: string, nullable: true }
 *             birthday: { type: string, format: date-time, nullable: true }
 *             joinedAt: { type: string, format: date-time, nullable: true }
 *         invitations:
 *           type: array
 *           items:
 *             type: object
 *             required: [id, kind, groupId, groupName, groupPicture, status, date]
 *             properties:
 *               id: { type: string }
 *               kind: { type: string, enum: [invite, request] }
 *               groupId: { type: string, nullable: true }
 *               groupName: { type: string, nullable: true }
 *               groupPicture: { type: string, nullable: true }
 *               status: { type: string, enum: [sent, requested, accepted, rejected, expired, withdrawn] }
 *               date: { type: string, format: date-time }
 *         events:
 *           type: array
 *           items:
 *             type: object
 *             required: [id, type, at, groupId, groupName, invitationId]
 *             properties:
 *               id: { type: string }
 *               type: { type: string, enum: [sent, resent, link_clicked, accepted, withdrawn, expired, requested, approved, rejected] }
 *               at: { type: string, format: date-time }
 *               groupId: { type: string, nullable: true }
 *               groupName: { type: string, nullable: true }
 *               invitationId: { type: string }
 *         canResend: { type: boolean }
 *         canWithdraw: { type: boolean }
 */

/**
 * @openapi
 * /api/invitations/feed:
 *   get:
 *     tags: [Invitations]
 *     summary: List invitations in manageable organizations
 *     description: Filters precede display-date ordering and the 200-row cap. Options describe the caller's full organization scope.
 *     security: [{ userSession: [] }]
 *     parameters:
 *       - { in: query, name: orgId, schema: { type: string, format: uuid } }
 *       - { in: query, name: groupId, schema: { type: string, format: uuid } }
 *       - { in: query, name: leaderId, schema: { type: string, format: uuid } }
 *       - { in: query, name: status, schema: { type: string, enum: [sent, requested, accepted, rejected, expired] } }
 *       - { in: query, name: limit, schema: { type: integer, minimum: 1, maximum: 200, default: 200 } }
 *     responses:
 *       200:
 *         description: Feed with total before limit and independent scoped filter options
 *         content: { application/json: { schema: { $ref: '#/components/schemas/InvitationFeed' } } }
 *       400: { description: Invalid filter, error string }
 *       401: { description: Not authenticated, standard authentication error }
 */
router.get('/feed', requireAuth, async (req, res) => {
  const parsed = feedQuery.safeParse(req.query)
  if (!parsed.success) return res.status(400).json({ error: 'Invalid invitation filters' })
  try { res.json(await getInvitationFeed((req.user as { id:string }).id, parsed.data)) }
  catch (error) {
    console.error('Error reading invitation feed:', error)
    res.status(500).json({ error: 'Internal server error' })
  }
})

/**
 * @openapi
 * /api/invitations/{id}:
 *   get:
 *     tags: [Invitations]
 *     summary: Get invitation detail and permitted phone history
 *     description: Null-phone rows are identity-scoped. Related rows and event group names are restricted to manageable organizations.
 *     security: [{ userSession: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200:
 *         description: Detail including the selected row in related history
 *         content: { application/json: { schema: { $ref: '#/components/schemas/InvitationDetail' } } }
 *       401: { description: Not authenticated, standard authentication error }
 *       403: { description: Invitation organization is not manageable, error string }
 *       404: { description: Invitation does not exist, error string }
 */
router.get('/:id', requireAuth, async (req, res) => {
  const parsed = uuid.safeParse(req.params.id)
  if (!parsed.success) return res.status(404).json({ error: 'Invitation not found' })
  try { res.json(await getInvitationDetail((req.user as { id:string }).id, parsed.data)) }
  catch (error) {
    if (error instanceof InvitationReadError) return res.status(error.status).json({ error: error.message })
    console.error('Error reading invitation detail:', error)
    res.status(500).json({ error: 'Internal server error' })
  }
})
export default router
