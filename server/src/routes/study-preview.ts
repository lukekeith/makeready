import { Router } from 'express'
import crypto from 'crypto'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import { requireAuth } from '../middleware/auth.js'

// ---------------------------------------------------------------------------
// In-memory token store (same pattern as authCodes / profileLinkTokens in auth.ts)
// ---------------------------------------------------------------------------

interface PreviewToken {
  studyProgramId: string
  creatorId: string
  expiresAt: number
  deviceId?: string // Set on first access — locks token to that browser
}

const previewTokens = new Map<string, PreviewToken>()

// Purge expired tokens every 10 minutes
setInterval(() => {
  const now = Date.now()
  for (const [token, data] of previewTokens) {
    if (data.expiresAt < now) {
      previewTokens.delete(token)
    }
  }
}, 10 * 60 * 1000)

// ---------------------------------------------------------------------------
// Helper: validate token + device-lock
// ---------------------------------------------------------------------------

function validateTokenAndDevice(
  token: string,
  req: any,
  res: any
): PreviewToken | null {
  const entry = previewTokens.get(token)

  if (!entry) {
    res.status(404).json({ success: false, error: 'Preview link not found' })
    return null
  }

  if (entry.expiresAt < Date.now()) {
    previewTokens.delete(token)
    res.status(410).json({ success: false, error: 'Preview link has expired' })
    return null
  }

  // Device-locking via cookie
  const cookieName = 'mr_preview_device'
  const existingDeviceId = req.cookies?.[cookieName] as string | undefined

  if (entry.deviceId) {
    if (existingDeviceId !== entry.deviceId) {
      res.status(403).json({
        success: false,
        error: 'This preview link is locked to another device',
      })
      return null
    }
  } else {
    const deviceId = existingDeviceId || crypto.randomBytes(16).toString('base64url')
    entry.deviceId = deviceId

    if (!existingDeviceId) {
      res.cookie(cookieName, deviceId, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        maxAge: 60 * 60 * 1000,
      })
    }
  }

  return entry
}

// ---------------------------------------------------------------------------
// Dev-only: generate preview token without auth
// ---------------------------------------------------------------------------

export const studyPreviewDevRouter = Router()

if (process.env.NODE_ENV !== 'production') {
  studyPreviewDevRouter.post('/', async (req, res) => {
    try {
      const body = generateTokenSchema.parse(req.body)

      const program = await prisma.studyProgram.findUnique({
        where: { id: body.studyProgramId },
        select: { id: true, creatorId: true },
      })

      if (!program) {
        return res.status(404).json({ success: false, error: 'Study program not found' })
      }

      const token = crypto.randomBytes(24).toString('base64url')
      const expiresAt = Date.now() + 60 * 60 * 1000

      previewTokens.set(token, {
        studyProgramId: body.studyProgramId,
        creatorId: program.creatorId,
        expiresAt,
      })

      const clientUrl = process.env.CLIENT_URL || 'http://localhost:8000'

      res.json({
        success: true,
        token,
        expiresAt: new Date(expiresAt).toISOString(),
        url: `${clientUrl}/public/preview/${token}`,
      })
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ success: false, error: 'Invalid request', details: error.errors })
      }
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  })
}

// ---------------------------------------------------------------------------
// Authenticated router — mounted at /api/study-preview
// ---------------------------------------------------------------------------

export const studyPreviewApiRouter = Router()

const generateTokenSchema = z.object({
  studyProgramId: z.string().uuid(),
})

/**
 * @openapi
 * /api/study-preview:
 *   post:
 *     tags: [Study Preview]
 *     summary: Generate a preview token for an entire study program
 *     description: |
 *       Creates a short-lived preview token so a program creator can preview
 *       all lessons in a study program. The token expires after 1 hour and
 *       is locked to the first device that opens it. Returns the token and
 *       a `routes.overview` URL for fetching the study overview.
 *     security:
 *       - session: []
 *       - apiKey: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [studyProgramId]
 *             properties:
 *               studyProgramId:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       200:
 *         description: Preview token generated
 *       403:
 *         description: Not the program creator
 *       404:
 *         description: Study program not found
 */
studyPreviewApiRouter.post('/', requireAuth, async (req, res) => {
  try {
    const body = generateTokenSchema.parse(req.body)
    const userId = (req.user as any).id

    // Fetch study program and verify the caller is in the same org
    const program = await prisma.studyProgram.findUnique({
      where: { id: body.studyProgramId },
      select: {
        id: true,
        creatorId: true,
        organizationId: true,
      },
    })

    if (!program) {
      return res.status(404).json({ success: false, error: 'Study program not found' })
    }

    // Allow access if the user is the creator OR belongs to the same org
    const callerUser = await prisma.user.findUnique({
      where: { id: userId },
      select: { organizationId: true },
    })
    const sameOrg = program.organizationId && callerUser?.organizationId === program.organizationId

    if (program.creatorId !== userId && !sameOrg) {
      return res.status(403).json({
        success: false,
        error: 'Only members of the same organization can generate preview links',
      })
    }

    // Generate cryptographic token (192 bits → 32-char base64url string)
    const token = crypto.randomBytes(24).toString('base64url')
    const expiresAt = Date.now() + 60 * 60 * 1000 // 1 hour

    previewTokens.set(token, {
      studyProgramId: body.studyProgramId,
      creatorId: userId,
      expiresAt,
    })

    const clientUrl = process.env.CLIENT_URL || 'http://localhost:5173'

    res.json({
      success: true,
      token,
      expiresAt: new Date(expiresAt).toISOString(),
      routes: {
        overview: `${clientUrl}/public/preview/${token}`,
      },
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: 'Invalid request', details: error.errors })
    }
    console.error('Error generating preview token:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

// ---------------------------------------------------------------------------
// Public router — mounted at /public/preview
// ---------------------------------------------------------------------------

export const studyPreviewPublicRouter = Router()

/**
 * @openapi
 * /public/preview/{token}:
 *   get:
 *     tags: [Study Preview]
 *     summary: Get study program overview for a preview token
 *     description: |
 *       No authentication required. Returns study program metadata and a list
 *       of lessons with their client routes so the iPhone/web app can navigate
 *       without hardcoding paths. On first access the token is locked to the
 *       requesting browser via a cookie. The token expires after 1 hour.
 *     parameters:
 *       - in: path
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Study program overview
 *       403:
 *         description: Token is locked to a different device
 *       404:
 *         description: Token not found
 *       410:
 *         description: Token has expired
 */
studyPreviewPublicRouter.get('/:token', async (req, res) => {
  try {
    const entry = validateTokenAndDevice(req.params.token, req, res)
    if (!entry) return

    const program = await prisma.studyProgram.findUnique({
      where: { id: entry.studyProgramId },
      select: {
        id: true,
        name: true,
        description: true,
        coverImageUrl: true,
        days: true,
        lessons: {
          orderBy: { dayNumber: 'asc' },
          select: {
            id: true,
            dayNumber: true,
            title: true,
            activities: {
              orderBy: { orderNumber: 'asc' },
              select: {
                activityType: true,
                title: true,
                sourceReferences: {
                  take: 1,
                  select: { passageReference: true },
                },
              },
            },
          },
        },
      },
    })

    if (!program) {
      return res.status(404).json({
        success: false,
        error: 'Study program no longer exists',
      })
    }

    const clientUrl = process.env.CLIENT_URL || 'http://localhost:5173'
    const token = req.params.token

    const lessons = program.lessons.map((lesson) => {
      const firstActivity = lesson.activities[0]
      const passageRef = firstActivity?.sourceReferences?.[0]?.passageReference
      const displayTitle = lesson.title || passageRef || firstActivity?.title || `Day ${lesson.dayNumber}`

      return {
        id: lesson.id,
        dayNumber: lesson.dayNumber,
        title: displayTitle,
        activities: lesson.activities.map((a) => a.activityType),
        routes: {
          lesson: `${clientUrl}/public/preview/${token}/lesson/${lesson.id}`,
        },
      }
    })

    res.json({
      success: true,
      program: {
        id: program.id,
        name: program.name,
        description: program.description,
        coverImageUrl: program.coverImageUrl,
        days: program.days,
        lessons,
      },
    })
  } catch (error) {
    console.error('Error fetching preview overview:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

/**
 * @openapi
 * /public/preview/{token}/lesson/{lessonId}:
 *   get:
 *     tags: [Study Preview]
 *     summary: Get full lesson data within a previewed study program
 *     description: |
 *       No authentication required. Returns full lesson data for a lesson
 *       that belongs to the token's study program. The token must already be
 *       device-locked (or will be locked on first access).
 *     parameters:
 *       - in: path
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: lessonId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Lesson data
 *       403:
 *         description: Token is locked to a different device or lesson doesn't belong to program
 *       404:
 *         description: Token or lesson not found
 *       410:
 *         description: Token has expired
 */
studyPreviewPublicRouter.get('/:token/lesson/:lessonId', async (req, res) => {
  try {
    const entry = validateTokenAndDevice(req.params.token, req, res)
    if (!entry) return

    const lesson = await prisma.lesson.findUnique({
      where: { id: req.params.lessonId },
      select: {
        id: true,
        dayNumber: true,
        studyProgramId: true,
        studyProgram: {
          select: {
            id: true,
            name: true,
            description: true,
            coverImageUrl: true,
            days: true,
          },
        },
        activities: {
          orderBy: { orderNumber: 'asc' },
          select: {
            id: true,
            activityType: true,
            orderNumber: true,
            title: true,
            isHelpEnabled: true,
            helpTitle: true,
            helpDescription: true,
            helpAlwaysVisible: true,
            helpIcon: true,
            referenceTitle: true,
            readContent: true,
            themeId: true,
            videoId: true,
            videoUrl: true,
            video: {
              select: {
                id: true,
                title: true,
                playbackUrl: true,
                thumbnailUrl: true,
                duration: true,
                status: true,
              },
            },
            sourceReferences: true,
            readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true, definition: true } }, exegesisHighlights: { orderBy: { orderNumber: 'asc' as const }, select: { id: true, orderNumber: true, start: true, end: true, noteMarkdown: true } } } },
          },
        },
      },
    })

    if (!lesson) {
      return res.status(404).json({
        success: false,
        error: 'Lesson not found',
      })
    }

    // Verify the lesson belongs to the token's study program
    if (lesson.studyProgramId !== entry.studyProgramId) {
      return res.status(403).json({
        success: false,
        error: 'This lesson does not belong to the previewed study program',
      })
    }

    // Remap activityType → type to match the format LessonIsland expects
    const formattedLesson = {
      ...lesson,
      activities: lesson.activities.map(a => ({
        ...a,
        type: a.activityType,
      })),
    }

    res.json({ success: true, lesson: formattedLesson })
  } catch (error) {
    console.error('Error fetching preview lesson:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

/**
 * @openapi
 * /public/preview/{token}/activity/{activityId}:
 *   get:
 *     tags: [Study Preview]
 *     summary: Get a single activity for standalone preview
 *     description: |
 *       No authentication required. Returns a single activity's full data
 *       for standalone rendering (no lesson navigation). The activity must
 *       belong to the token's study program.
 *     parameters:
 *       - in: path
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: activityId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Activity data
 *       403:
 *         description: Token is locked to a different device or activity doesn't belong to program
 *       404:
 *         description: Token or activity not found
 *       410:
 *         description: Token has expired
 */
studyPreviewPublicRouter.get('/:token/activity/:activityId', async (req, res) => {
  try {
    // Skip device locking for activity previews — these are opened in a WebView
    // from the iPhone app which has a different cookie jar than the native client
    // that generated the token. The token is already short-lived and creator-only.
    const entry = previewTokens.get(req.params.token)

    if (!entry) {
      return res.status(404).json({ success: false, error: 'Preview link not found' })
    }

    if (entry.expiresAt < Date.now()) {
      previewTokens.delete(req.params.token)
      return res.status(410).json({ success: false, error: 'Preview link has expired' })
    }

    const activity = await prisma.lessonActivity.findUnique({
      where: { id: req.params.activityId },
      select: {
        id: true,
        activityType: true,
        orderNumber: true,
        title: true,
        isHelpEnabled: true,
        helpTitle: true,
        helpDescription: true,
        helpAlwaysVisible: true,
        helpIcon: true,
        referenceTitle: true,
        readContent: true,
        themeId: true,
        videoId: true,
        videoUrl: true,
        video: {
          select: {
            id: true,
            title: true,
            playbackUrl: true,
            thumbnailUrl: true,
            duration: true,
            status: true,
          },
        },
        sourceReferences: true,
        readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true, definition: true } }, exegesisHighlights: { orderBy: { orderNumber: 'asc' as const }, select: { id: true, orderNumber: true, start: true, end: true, noteMarkdown: true } } } },
        lesson: {
          select: {
            studyProgramId: true,
          },
        },
      },
    })

    if (!activity) {
      return res.status(404).json({ success: false, error: 'Activity not found' })
    }

    // Verify the activity belongs to the token's study program
    if (activity.lesson.studyProgramId !== entry.studyProgramId) {
      return res.status(403).json({ success: false, error: 'This activity does not belong to the previewed study program' })
    }

    // Format: remap activityType → type, strip lesson data
    const { lesson: _lesson, ...activityWithoutLesson } = activity
    const formatted = {
      ...activityWithoutLesson,
      type: activity.activityType,
    }

    res.json({ success: true, activity: formatted })
  } catch (error) {
    console.error('Error fetching preview activity:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

// ---------------------------------------------------------------------------
// Preview State router — mounted at /api/preview
// Stores interactive preview data (notes, video progress, exegesis visits)
// tied to a DB-backed preview token. No member enrollment required.
// ---------------------------------------------------------------------------

export const previewStateRouter = Router()

/**
 * Merge saved preview state (notes, video progress, exegesis visits) into
 * activity data so LessonIsland sees pre-populated content on reload.
 */
async function mergePreviewState(previewTokenId: string, activities: any[]): Promise<any[]> {
  const states = await prisma.previewState.findMany({
    where: { previewTokenId },
    select: { entityType: true, activityId: true, data: true },
  })

  if (states.length === 0) return activities

  const stateMap = new Map<string, Map<string, any>>()
  for (const s of states) {
    if (!stateMap.has(s.activityId)) stateMap.set(s.activityId, new Map())
    stateMap.get(s.activityId)!.set(s.entityType, s.data)
  }

  return activities.map(activity => {
    const activityStates = stateMap.get(activity.id)
    if (!activityStates) return activity

    const merged = { ...activity }

    const noteState = activityStates.get('note')
    if (noteState) {
      merged.note = { content: (noteState as any).content }
    }

    const videoState = activityStates.get('video_progress')
    if (videoState) {
      merged.progress = {
        ...(merged.progress ?? {}),
        completedAt: (videoState as any).progress >= 0.9 ? new Date().toISOString() : null,
      }
    }

    const exegesisState = activityStates.get('exegesis_visit')
    if (exegesisState) {
      merged.progress = {
        ...(merged.progress ?? {}),
        exegesisVisitedHighlightIds: (exegesisState as any).visitedIds ?? [],
      }
    }

    return merged
  })
}

/**
 * Resolve a DB-backed preview token. Returns the token record or sends
 * an error response and returns null.
 */
async function resolveDbToken(token: string, res: any) {
  const record = await prisma.previewToken.findUnique({
    where: { token },
    select: { id: true, userId: true, organizationId: true },
  })
  if (!record) {
    res.status(404).json({ success: false, error: 'Preview token not found' })
    return null
  }
  return record
}

// POST /api/preview/:token/state/note/:activityId
previewStateRouter.post('/:token/state/note/:activityId', async (req, res) => {
  try {
    const tokenRecord = await resolveDbToken(req.params.token, res)
    if (!tokenRecord) return

    const { note } = req.body ?? {}
    const content = note?.content ?? ''
    const noteType = note?.type ?? 'NOTE'

    await prisma.previewState.upsert({
      where: {
        previewTokenId_entityType_activityId: {
          previewTokenId: tokenRecord.id,
          entityType: 'note',
          activityId: req.params.activityId,
        },
      },
      update: { data: { type: noteType, content } as unknown as Prisma.InputJsonValue },
      create: {
        previewTokenId: tokenRecord.id,
        entityType: 'note',
        activityId: req.params.activityId,
        data: { type: noteType, content } as unknown as Prisma.InputJsonValue,
      },
    })

    res.json({ success: true })
  } catch (error) {
    console.error('Error saving preview note:', error)
    res.status(500).json({ success: false, error: 'Failed to save preview note' })
  }
})

// POST /api/preview/:token/state/video-progress/:activityId
previewStateRouter.post('/:token/state/video-progress/:activityId', async (req, res) => {
  try {
    const tokenRecord = await resolveDbToken(req.params.token, res)
    if (!tokenRecord) return

    const { progress } = req.body ?? {}

    await prisma.previewState.upsert({
      where: {
        previewTokenId_entityType_activityId: {
          previewTokenId: tokenRecord.id,
          entityType: 'video_progress',
          activityId: req.params.activityId,
        },
      },
      update: { data: { progress } as unknown as Prisma.InputJsonValue },
      create: {
        previewTokenId: tokenRecord.id,
        entityType: 'video_progress',
        activityId: req.params.activityId,
        data: { progress } as unknown as Prisma.InputJsonValue,
      },
    })

    res.json({ success: true })
  } catch (error) {
    console.error('Error saving preview video progress:', error)
    res.status(500).json({ success: false, error: 'Failed to save preview video progress' })
  }
})

// POST /api/preview/:token/state/exegesis-visit/:activityId
previewStateRouter.post('/:token/state/exegesis-visit/:activityId', async (req, res) => {
  try {
    const tokenRecord = await resolveDbToken(req.params.token, res)
    if (!tokenRecord) return

    const { highlightId } = req.body ?? {}
    if (!highlightId) {
      return res.status(400).json({ success: false, error: 'highlightId is required' })
    }

    // Load existing visited IDs and merge
    const existing = await prisma.previewState.findUnique({
      where: {
        previewTokenId_entityType_activityId: {
          previewTokenId: tokenRecord.id,
          entityType: 'exegesis_visit',
          activityId: req.params.activityId,
        },
      },
      select: { data: true },
    })

    const visitedIds: string[] = (existing?.data as any)?.visitedIds ?? []
    if (!visitedIds.includes(highlightId)) {
      visitedIds.push(highlightId)
    }

    await prisma.previewState.upsert({
      where: {
        previewTokenId_entityType_activityId: {
          previewTokenId: tokenRecord.id,
          entityType: 'exegesis_visit',
          activityId: req.params.activityId,
        },
      },
      update: { data: { visitedIds } as unknown as Prisma.InputJsonValue },
      create: {
        previewTokenId: tokenRecord.id,
        entityType: 'exegesis_visit',
        activityId: req.params.activityId,
        data: { visitedIds } as unknown as Prisma.InputJsonValue,
      },
    })

    res.json({
      success: true,
      data: { exegesisVisitedHighlightIds: visitedIds },
    })
  } catch (error) {
    console.error('Error saving preview exegesis visit:', error)
    res.status(500).json({ success: false, error: 'Failed to save preview exegesis visit' })
  }
})
