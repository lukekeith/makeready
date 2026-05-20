import { Router } from 'express';
import { prisma } from '../lib/prisma.js';

const router = Router();

/**
 * @openapi
 * /api/status:
 *   get:
 *     tags: [Status]
 *     summary: Get system status
 *     description: |
 *       Returns comprehensive server health, database connection status, and uptime information.
 *       This endpoint does not require authentication and is suitable for health checks and monitoring.
 *     security: []
 *     responses:
 *       200:
 *         description: System status retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required:
 *                 - success
 *                 - status
 *                 - timestamp
 *                 - database
 *                 - server
 *               properties:
 *                 success:
 *                   type: boolean
 *                   description: Indicates the request was successful
 *                   example: true
 *                 status:
 *                   type: string
 *                   description: Overall system status
 *                   enum: [operational, error]
 *                   example: operational
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                   description: ISO 8601 timestamp of when the status was generated
 *                   example: "2024-01-15T10:30:00.000Z"
 *                 database:
 *                   type: object
 *                   description: Database connection health information
 *                   required:
 *                     - status
 *                     - responseTime
 *                   properties:
 *                     status:
 *                       type: string
 *                       description: Database connection status
 *                       enum: [healthy, unhealthy]
 *                       example: healthy
 *                     responseTime:
 *                       type: string
 *                       description: Time taken to query the database
 *                       example: "5ms"
 *                 server:
 *                   type: object
 *                   description: Server runtime information
 *                   required:
 *                     - uptime
 *                     - uptimeSeconds
 *                     - environment
 *                     - nodeVersion
 *                   properties:
 *                     uptime:
 *                       type: string
 *                       description: Human-readable server uptime
 *                       example: "2d 5h 30m 15s"
 *                     uptimeSeconds:
 *                       type: integer
 *                       description: Server uptime in seconds
 *                       example: 192615
 *                     environment:
 *                       type: string
 *                       description: Current Node.js environment
 *                       enum: [development, production, test]
 *                       example: production
 *                     nodeVersion:
 *                       type: string
 *                       description: Node.js version running the server
 *                       example: "v20.10.0"
 *             example:
 *               success: true
 *               status: operational
 *               timestamp: "2024-01-15T10:30:00.000Z"
 *               database:
 *                 status: healthy
 *                 responseTime: "5ms"
 *               server:
 *                 uptime: "2d 5h 30m 15s"
 *                 uptimeSeconds: 192615
 *                 environment: production
 *                 nodeVersion: "v20.10.0"
 *       500:
 *         description: Internal server error while generating status report
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required:
 *                 - success
 *                 - status
 *                 - error
 *               properties:
 *                 success:
 *                   type: boolean
 *                   description: Indicates the request failed
 *                   example: false
 *                 status:
 *                   type: string
 *                   description: Error status indicator
 *                   example: error
 *                 error:
 *                   type: string
 *                   description: Error message describing the failure
 *                   example: "Failed to generate status report"
 *             example:
 *               success: false
 *               status: error
 *               error: "Failed to generate status report"
 */
router.get('/', async (_req, res) => {
  const startTime = Date.now();

  try {
    // Check database connection
    let dbStatus: 'healthy' | 'unhealthy' = 'unhealthy';
    try {
      await prisma.$queryRaw`SELECT 1`;
      dbStatus = 'healthy';
    } catch (dbError) {
      console.error('[Status] Database health check failed:', dbError);
    }

    // Calculate uptime
    const uptime = process.uptime();
    const uptimeFormatted = formatUptime(uptime);

    // Get environment and version info
    const environment = process.env.NODE_ENV || 'development';
    const nodeVersion = process.version;

    const responseTime = Date.now() - startTime;

    res.json({
      success: true,
      status: 'operational',
      timestamp: new Date().toISOString(),
      database: {
        status: dbStatus,
        responseTime: `${responseTime}ms`,
      },
      server: {
        uptime: uptimeFormatted,
        uptimeSeconds: Math.floor(uptime),
        environment,
        nodeVersion,
      },
    });
  } catch (error) {
    console.error('[Status] Error generating status:', error);
    res.status(500).json({
      success: false,
      status: 'error',
      error: 'Failed to generate status report',
    });
  }
});

/**
 * Format uptime in human-readable format
 */
function formatUptime(seconds: number): string {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);

  const parts: string[] = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  if (secs > 0 || parts.length === 0) parts.push(`${secs}s`);

  return parts.join(' ');
}

/**
 * Performance benchmark endpoint - measures DB latency for critical queries
 */
router.get('/perf', async (_req, res) => {
  try {
    const time = async (fn: () => Promise<unknown>): Promise<number> => {
      const start = performance.now();
      await fn();
      return performance.now() - start;
    };

    // 1. Raw ping (x10 for stats)
    const pingTimes: number[] = [];
    for (let i = 0; i < 10; i++) {
      pingTimes.push(await time(() => prisma.$queryRaw`SELECT 1`));
    }
    const sorted = [...pingTimes].sort((a, b) => a - b);
    const avg = pingTimes.reduce((a, b) => a + b, 0) / pingTimes.length;

    // 2. Direct verse lookup (most common query - user taps a reference)
    const verseLookup = await time(() =>
      prisma.$queryRaw`
        SELECT v.id, v.text, v.chapter, v.verse
        FROM verses v
        JOIN translations t ON v."translationId" = t.id
        WHERE t.code = 'KJV' AND v."bookNumber" = 43 AND v.chapter = 3 AND v.verse = 16
        LIMIT 1
      `
    );

    // 3. Chapter load (user opens a chapter - loads ~30 verses)
    const chapterLoad = await time(() =>
      prisma.$queryRaw`
        SELECT v.id, v.verse, v.text
        FROM verses v
        JOIN translations t ON v."translationId" = t.id
        WHERE t.code = 'KJV' AND v."bookNumber" = 43 AND v.chapter = 3
        ORDER BY v.verse
      `
    );

    // 4. Full-text search (Bible search bar)
    const ftsSearch = await time(() =>
      prisma.$queryRaw`
        SELECT v.id, v.text, b."bookName", v.chapter, v.verse,
          ts_rank(v."searchVector", plainto_tsquery('english', 'love')) as rank
        FROM verses v
        JOIN books b ON v."bookId" = b.id
        JOIN translations t ON v."translationId" = t.id
        WHERE t.code = 'KJV' AND v."searchVector" @@ plainto_tsquery('english', 'love')
        ORDER BY rank DESC LIMIT 20
      `
    );

    // 5. Books list (Bible navigation - loads all 66 books)
    const booksList = await time(() =>
      prisma.$queryRaw`
        SELECT b.id, b."bookName", b."bookAbbrev", b."bookNumber", b.chapters
        FROM books b
        JOIN translations t ON b."translationId" = t.id
        WHERE t.code = 'KJV'
        ORDER BY b."bookNumber"
      `
    );

    // 6. Member profile with organizations (auth check on every request)
    const memberLookup = await time(() =>
      prisma.member.findFirst({
        where: { isActive: true },
        select: {
          id: true,
          firstName: true,
          lastName: true,
          organizations: {
            select: { organizationId: true },
          },
        },
      })
    );

    // 7. Groups list with member count (home screen)
    const groupsList = await time(() =>
      prisma.group.findMany({
        where: { isActive: true },
        take: 10,
        orderBy: { updatedAt: 'desc' },
        select: {
          id: true,
          name: true,
          code: true,
          _count: { select: { members: { where: { isActive: true } } } },
        },
      })
    );

    // 8. Enrollment with lesson schedules (study view)
    const enrollmentLoad = await time(() =>
      prisma.enrollment.findFirst({
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          studyProgram: { select: { id: true, name: true } },
          lessonSchedules: {
            take: 10,
            orderBy: { scheduledDate: 'asc' },
            select: {
              id: true,
              scheduledDate: true,
              lesson: { select: { id: true, dayNumber: true } },
            },
          },
        },
      })
    );

    res.json({
      timestamp: new Date().toISOString(),
      connection: {
        host: (process.env.DIRECT_URL || '').match(/@([^:\/]+)/)?.[1] || 'unknown',
        ssl: (process.env.DIRECT_URL || '').includes('sslmode=disable') ? 'disabled' : 'enabled',
        poolSize: 20,
      },
      ping: {
        min: +sorted[0].toFixed(1),
        max: +sorted[sorted.length - 1].toFixed(1),
        avg: +avg.toFixed(1),
        p95: +sorted[Math.floor(9 * 0.95)].toFixed(1),
        samples: pingTimes.map(t => +t.toFixed(1)),
      },
      queries: [
        { name: 'Verse Lookup', description: 'Single verse by reference (John 3:16)', time: +verseLookup.toFixed(1), category: 'bible' },
        { name: 'Chapter Load', description: 'All verses in John 3 (~36 rows)', time: +chapterLoad.toFixed(1), category: 'bible' },
        { name: 'Full-Text Search', description: 'FTS "love" with ranking, limit 20', time: +ftsSearch.toFixed(1), category: 'bible' },
        { name: 'Books List', description: 'All 66 books for Bible navigation', time: +booksList.toFixed(1), category: 'bible' },
        { name: 'Member Profile', description: 'Member with org memberships (auth path)', time: +memberLookup.toFixed(1), category: 'auth' },
        { name: 'Groups List', description: 'Active groups with member counts', time: +groupsList.toFixed(1), category: 'app' },
        { name: 'Study Progress', description: 'Enrollment with lesson schedules', time: +enrollmentLoad.toFixed(1), category: 'app' },
      ],
    });
  } catch (error) {
    console.error('[Perf] Error:', error);
    res.status(500).json({ error: 'Performance benchmark failed', details: String(error) });
  }
});

export default router;
