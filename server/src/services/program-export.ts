import { z } from 'zod'
import archiver from 'archiver'
import AdmZip from 'adm-zip'
import { PassThrough } from 'stream'
import { prisma } from '../lib/prisma.js'
import { normalizeScriptureMarkdown } from '../utils/scripture-content-normalizer.js'

// ============================================================================
// Manifest Schema (Zod validation for import)
// ============================================================================

const sourceReferenceSchema = z.object({
  sourceType: z.string(),
  passageReference: z.string().nullable().optional(),
  bookNumber: z.number().int().nullable().optional(),
  bookName: z.string().nullable().optional(),
  chapterStart: z.number().int().nullable().optional(),
  chapterEnd: z.number().int().nullable().optional(),
  verseStart: z.number().int().nullable().optional(),
  verseEnd: z.number().int().nullable().optional(),
})

const readBlockSchema = z.object({
  orderNumber: z.number().int(),
  title: z.string().nullable().optional(),
  content: z.string().nullable().optional(),
  contentFormat: z.string().default('html'),
  isLocked: z.boolean().default(false),
  sourceReferenceIndex: z.number().int().nullable().optional(),
  themeSlug: z.string().nullable().optional(),
  backgroundImageUrl: z.string().nullable().optional(),
  backgroundColor: z.string().nullable().optional(),
  backgroundOverlayOpacity: z.number().min(0).max(1).nullable().optional(),
  fontSize: z.enum(['xs', 's', 'm', 'lg', 'xl']).nullable().optional(),
})

const themeSchema = z.object({
  slug: z.string(),
  name: z.string(),
  description: z.string().nullable().optional(),
  definition: z.any(),
  isSystem: z.boolean().default(false),
})

const videoSchema = z.object({
  cloudflareUid: z.string().optional(),
  playbackUrl: z.string(),
  thumbnailUrl: z.string().nullable().optional(),
  duration: z.number().int().nullable().optional(),
  title: z.string().nullable().optional(),
})

const activitySchema = z.object({
  activityType: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']),
  orderNumber: z.number().int(),
  title: z.string(),
  helpTitle: z.string().nullable().optional(),
  helpDescription: z.string().nullable().optional(),
  helpAlwaysVisible: z.boolean().default(false),
  referenceTitle: z.string().nullable().optional(),
  readContent: z.string().nullable().optional(),
  themeSlug: z.string().nullable().optional(),
  video: videoSchema.nullable().optional(),
  sourceReferences: z.array(sourceReferenceSchema).default([]),
  readBlocks: z.array(readBlockSchema).default([]),
})

const templateActivitySchema = z.object({
  type: z.enum(['USER_INPUT', 'READ', 'VIDEO', 'YOUTUBE', 'EXEGESIS']),
  orderNumber: z.number().int(),
  title: z.string(),
  displayName: z.string().nullable().optional(),
  helpTitle: z.string().nullable().optional(),
  helpDescription: z.string().nullable().optional(),
  helpAlwaysVisible: z.boolean().default(false),
  referenceTitle: z.string().nullable().optional(),
})

const manifestSchema = z.object({
  version: z.literal(1),
  format: z.literal('makeready-program-v1'),
  exportedAt: z.string(),
  exportedBy: z.string().optional(),
  sourceOrganization: z.string().optional(),
  // Themes referenced by any activity or readBlock, bundled so imports into
  // a different instance can recreate the same visual style without depending
  // on the destination database already having matching slugs. Resolved by
  // slug on import — existing themes (matching slug) are preserved, missing
  // ones are created as non-system themes owned by the importer.
  themes: z.array(themeSchema).default([]),
  program: z.object({
    name: z.string().min(1).max(200),
    description: z.string().nullable().optional(),
    days: z.number().int().min(1).max(360),
    coverImageUrl: z.string().nullable().optional(),
    requireResponse: z.boolean().default(true),
    template: z.object({
      name: z.string(),
      description: z.string().nullable().optional(),
      activities: z.array(templateActivitySchema),
    }),
    lessons: z.array(z.object({
      dayNumber: z.number().int(),
      title: z.string().nullable().optional(),
      activities: z.array(activitySchema),
    })),
  }),
})

type Manifest = z.infer<typeof manifestSchema>

// ============================================================================
// Export
// ============================================================================

export async function exportProgram(programId: string, userId: string): Promise<{
  success: boolean
  buffer?: Buffer
  filename?: string
  error?: string
}> {
  // Determine org-scoped or creator-scoped access
  const userOrg = await prisma.organization.findFirst({
    where: { ownerId: userId },
    select: { id: true },
  })
  const access = userOrg ? { organizationId: userOrg.id } : { creatorId: userId }

  // Fetch program with all nested relations (no pagination — export needs everything)
  const program = await prisma.studyProgram.findFirst({
    where: { id: programId, ...access, isActive: true },
    include: {
      template: {
        include: {
          activities: { orderBy: { orderNumber: 'asc' } },
        },
      },
      lessons: {
        orderBy: { dayNumber: 'asc' },
        include: {
          activities: {
            orderBy: { orderNumber: 'asc' },
            include: {
              video: true,
              theme: { select: { id: true, slug: true, name: true, description: true, definition: true, isSystem: true } },
              sourceReferences: { orderBy: { id: 'asc' } },
              readBlocks: {
                orderBy: { orderNumber: 'asc' },
                include: {
                  theme: { select: { id: true, slug: true, name: true, description: true, definition: true, isSystem: true } },
                },
              },
            },
          },
        },
      },
    },
  })

  if (!program) {
    return { success: false, error: 'Program not found' }
  }

  // Look up creator info and org name for metadata
  const creator = await prisma.user.findUnique({
    where: { id: userId },
    select: { name: true },
  })

  const org = program.organizationId
    ? await prisma.organization.findUnique({
        where: { id: program.organizationId },
        select: { name: true },
      })
    : null

  // Collect every theme referenced anywhere in the program — activity-level
  // and block-level — keyed by slug to dedupe. Shipped alongside the program
  // so the destination instance can recreate them on import.
  const themeMap = new Map<string, {
    slug: string
    name: string
    description: string | null
    definition: unknown
    isSystem: boolean
  }>()
  for (const lesson of program.lessons) {
    for (const activity of lesson.activities) {
      const actTheme = (activity as any).theme
      if (actTheme?.slug && !themeMap.has(actTheme.slug)) {
        themeMap.set(actTheme.slug, {
          slug: actTheme.slug,
          name: actTheme.name,
          description: actTheme.description ?? null,
          definition: actTheme.definition,
          isSystem: actTheme.isSystem ?? false,
        })
      }
      for (const rb of activity.readBlocks) {
        const blockTheme = (rb as any).theme
        if (blockTheme?.slug && !themeMap.has(blockTheme.slug)) {
          themeMap.set(blockTheme.slug, {
            slug: blockTheme.slug,
            name: blockTheme.name,
            description: blockTheme.description ?? null,
            definition: blockTheme.definition,
            isSystem: blockTheme.isSystem ?? false,
          })
        }
      }
    }
  }

  // Build manifest
  const manifest: Manifest = {
    version: 1,
    format: 'makeready-program-v1',
    exportedAt: new Date().toISOString(),
    exportedBy: creator?.name ?? undefined,
    sourceOrganization: org?.name ?? undefined,
    themes: Array.from(themeMap.values()),
    program: {
      name: program.name,
      description: program.description,
      days: program.days,
      coverImageUrl: program.coverImageUrl,
      requireResponse: program.requireResponse,
      template: program.template
        ? {
            name: program.template.name,
            description: program.template.description,
            activities: program.template.activities.map((ta) => ({
              type: ta.type as 'USER_INPUT' | 'READ' | 'VIDEO' | 'YOUTUBE' | 'EXEGESIS',
              orderNumber: ta.orderNumber,
              title: ta.title,
              displayName: ta.displayName,
              helpTitle: ta.helpTitle,
              helpDescription: ta.helpDescription,
              helpAlwaysVisible: ta.helpAlwaysVisible,
              helpIcon: ta.helpIcon,
              referenceTitle: ta.referenceTitle,
            })),
          }
        : { name: 'Default', description: null, activities: [] },
      lessons: program.lessons.map((lesson) => ({
        dayNumber: lesson.dayNumber,
        title: lesson.title,
        activities: lesson.activities.map((activity) => ({
          activityType: activity.activityType as 'USER_INPUT' | 'READ' | 'VIDEO' | 'YOUTUBE' | 'EXEGESIS',
          orderNumber: activity.orderNumber,
          title: activity.title,
          helpTitle: activity.helpTitle,
          helpDescription: activity.helpDescription,
          helpAlwaysVisible: activity.helpAlwaysVisible,
          helpIcon: activity.helpIcon,
          referenceTitle: activity.referenceTitle,
          readContent: activity.readContent,
          themeSlug: activity.theme?.slug ?? null,
          video: activity.video
            ? {
                cloudflareUid: activity.video.cloudflareUid,
                playbackUrl: activity.video.playbackUrl,
                thumbnailUrl: activity.video.thumbnailUrl,
                duration: activity.video.duration,
                title: activity.video.title,
              }
            : activity.videoUrl
              ? { playbackUrl: activity.videoUrl }
              : null,
          sourceReferences: activity.sourceReferences.map((sr) => ({
            sourceType: sr.sourceType,
            passageReference: sr.passageReference,
            bookNumber: sr.bookNumber,
            bookName: sr.bookName,
            chapterStart: sr.chapterStart,
            chapterEnd: sr.chapterEnd,
            verseStart: sr.verseStart,
            verseEnd: sr.verseEnd,
          })),
          readBlocks: activity.readBlocks.map((rb) => ({
            orderNumber: rb.orderNumber,
            title: rb.title,
            content: rb.content,
            contentFormat: rb.contentFormat ?? 'html',
            isLocked: rb.isLocked,
            sourceReferenceIndex: rb.sourceReferenceId
              ? activity.sourceReferences.findIndex((sr) => sr.id === rb.sourceReferenceId)
              : null,
            themeSlug: (rb as any).theme?.slug ?? null,
            backgroundImageUrl: (rb as any).backgroundImageUrl ?? null,
            backgroundColor: (rb as any).backgroundColor ?? null,
            backgroundOverlayOpacity: (rb as any).backgroundOverlayOpacity ?? null,
            fontSize: (rb as any).fontSize ?? null,
          })),
        })),
      })),
    },
  }

  // Create ZIP buffer
  const buffer = await createZipBuffer(manifest)
  const slug = program.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
  const filename = `program-export-${slug}.zip`

  return { success: true, buffer, filename }
}

async function createZipBuffer(manifest: Manifest): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = []
    const passthrough = new PassThrough()

    passthrough.on('data', (chunk: Buffer) => chunks.push(chunk))
    passthrough.on('end', () => resolve(Buffer.concat(chunks)))
    passthrough.on('error', reject)

    const archive = archiver('zip', { zlib: { level: 9 } })
    archive.on('error', reject)
    archive.pipe(passthrough)
    archive.append(JSON.stringify(manifest, null, 2), { name: 'manifest.json' })
    archive.finalize()
  })
}

// ============================================================================
// Import
// ============================================================================

export async function importProgram(zipBuffer: Buffer, userId: string): Promise<{
  success: boolean
  program?: any
  warnings?: string[]
  error?: string
}> {
  // Parse ZIP and extract manifest
  const zip = new AdmZip(zipBuffer)
  const manifestEntry = zip.getEntry('manifest.json')

  if (!manifestEntry) {
    return { success: false, error: 'ZIP does not contain manifest.json' }
  }

  let rawManifest: unknown
  try {
    rawManifest = JSON.parse(manifestEntry.getData().toString('utf8'))
  } catch {
    return { success: false, error: 'manifest.json is not valid JSON' }
  }

  // Validate manifest
  const parsed = manifestSchema.safeParse(rawManifest)
  if (!parsed.success) {
    return {
      success: false,
      error: `Invalid manifest: ${parsed.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join('; ')}`,
    }
  }

  const manifest = parsed.data
  const warnings: string[] = []

  // Check for video references
  const hasVideos = manifest.program.lessons.some((l) =>
    l.activities.some((a) => a.video)
  )
  if (hasVideos) {
    warnings.push('This program contains video references. Videos are linked by URL and are not owned by your account.')
  }

  // Look up importing user's organization
  const creatorOrg = await prisma.organization.findFirst({
    where: { ownerId: userId },
    select: { id: true },
  })

  // Run entire import in a transaction
  const program = await prisma.$transaction(async (tx) => {
    // 0. Recreate any bundled themes that don't already exist locally.
    //    Lookup is by `slug` (unique). Existing themes — including system
    //    ones — are left untouched so we never mutate shared visuals.
    //    Missing themes are created as non-system themes owned by the
    //    importing user + their org. After this runs, the existing slug→
    //    id resolution below will find every theme the manifest needs.
    for (const themeData of manifest.themes) {
      const existing = await tx.textTheme.findUnique({ where: { slug: themeData.slug } })
      if (existing) continue
      await tx.textTheme.create({
        data: {
          slug: themeData.slug,
          name: themeData.name,
          description: themeData.description ?? null,
          definition: themeData.definition as any,
          // Imported themes are always user-owned; we never stamp isSystem
          // on an import, even if the source marked it system.
          isSystem: false,
          isActive: true,
          creatorId: userId,
          organizationId: creatorOrg?.id ?? null,
        },
      })
    }

    // 1. Create LessonTemplate from manifest
    const newTemplate = await tx.lessonTemplate.create({
      data: {
        name: `${manifest.program.template.name} (imported)`,
        description: manifest.program.template.description,
        isSystem: false,
        creatorId: userId,
        organizationId: creatorOrg?.id,
        isActive: true,
      },
    })

    // Create template activities
    if (manifest.program.template.activities.length > 0) {
      await tx.lessonTemplateActivity.createMany({
        data: manifest.program.template.activities.map((ta) => ({
          templateId: newTemplate.id,
          type: ta.type,
          orderNumber: ta.orderNumber,
          title: ta.title,
          displayName: ta.displayName ?? null,
          helpTitle: ta.helpTitle ?? null,
          helpDescription: ta.helpDescription ?? null,
          helpAlwaysVisible: ta.helpAlwaysVisible,
          referenceTitle: ta.referenceTitle ?? null,
        })),
      })
    }

    // 2. Create StudyProgram (always as draft)
    const newProgram = await tx.studyProgram.create({
      data: {
        name: manifest.program.name,
        description: manifest.program.description ?? null,
        days: manifest.program.days,
        coverImageUrl: manifest.program.coverImageUrl ?? null,
        requireResponse: manifest.program.requireResponse,
        templateId: newTemplate.id,
        isPublished: false,
        creatorId: userId,
        organizationId: creatorOrg?.id,
      },
    })

    // 3. Create Lessons and Activities
    for (const lessonData of manifest.program.lessons) {
      const lesson = await tx.lesson.create({
        data: {
          studyProgramId: newProgram.id,
          dayNumber: lessonData.dayNumber,
          title: lessonData.title ?? null,
        },
      })

      for (const actData of lessonData.activities) {
        // Resolve activity-level theme by slug
        let activityThemeId: string | null = null
        if (actData.themeSlug) {
          const actTheme = await tx.textTheme.findUnique({ where: { slug: actData.themeSlug } })
          if (actTheme) {
            activityThemeId = actTheme.id
          } else {
            warnings.push(`Theme "${actData.themeSlug}" not found, skipping theme for activity "${actData.title}"`)
          }
        }

        const activity = await tx.lessonActivity.create({
          data: {
            lessonId: lesson.id,
            activityType: actData.activityType,
            orderNumber: actData.orderNumber,
            title: actData.title,
            helpTitle: actData.helpTitle ?? null,
            helpDescription: actData.helpDescription ?? null,
            helpAlwaysVisible: actData.helpAlwaysVisible,
            referenceTitle: actData.referenceTitle ?? null,
            readContent: actData.readContent ?? null,
            videoUrl: actData.video?.playbackUrl ?? null,
            themeId: activityThemeId,
            // videoId left null — importer doesn't own the video
          },
        })

        // Create source references and build index→id map
        const sourceRefIdMap = new Map<number, string>()
        for (let i = 0; i < actData.sourceReferences.length; i++) {
          const sr = actData.sourceReferences[i]
          const created = await tx.activitySourceReference.create({
            data: {
              lessonActivityId: activity.id,
              sourceType: sr.sourceType,
              passageReference: sr.passageReference ?? null,
              bookNumber: sr.bookNumber ?? null,
              bookName: sr.bookName ?? null,
              chapterStart: sr.chapterStart ?? null,
              chapterEnd: sr.chapterEnd ?? null,
              verseStart: sr.verseStart ?? null,
              verseEnd: sr.verseEnd ?? null,
            },
          })
          sourceRefIdMap.set(i, created.id)
        }

        // Create read blocks, resolving sourceReferenceIndex to real FK
        for (const rb of actData.readBlocks) {
          const sourceReferenceId =
            rb.sourceReferenceIndex != null
              ? sourceRefIdMap.get(rb.sourceReferenceIndex) ?? null
              : null

          // Resolve block-level theme by slug
          let blockThemeId: string | null = null
          if (rb.themeSlug) {
            const blockTheme = await tx.textTheme.findUnique({ where: { slug: rb.themeSlug } })
            if (blockTheme) {
              blockThemeId = blockTheme.id
            } else {
              warnings.push(`Theme "${rb.themeSlug}" not found, skipping theme for read block "${rb.title ?? `#${rb.orderNumber}`}"`)
            }
          }

          const isScriptureLinkedBlock = sourceReferenceId != null
          const content = isScriptureLinkedBlock
            ? normalizeScriptureMarkdown(rb.content)
            : (rb.content ?? null)

          await tx.activityReadBlock.create({
            data: {
              lessonActivityId: activity.id,
              orderNumber: rb.orderNumber,
              title: rb.title ?? null,
              content,
              contentFormat: isScriptureLinkedBlock ? 'markdown' : (rb.contentFormat ?? 'html'),
              isLocked: rb.isLocked,
              sourceReferenceId,
              themeId: blockThemeId,
              backgroundImageUrl: rb.backgroundImageUrl ?? null,
              backgroundColor: rb.backgroundColor ?? null,
              backgroundOverlayOpacity: rb.backgroundOverlayOpacity ?? null,
              fontSize: rb.fontSize ?? null,
            },
          })
        }
      }
    }

    // 4. Return full program with all includes
    return tx.studyProgram.findUnique({
      where: { id: newProgram.id },
      include: {
        template: {
          select: { id: true, name: true },
        },
        lessons: {
          orderBy: { dayNumber: 'asc' },
          include: {
            activities: {
              orderBy: { orderNumber: 'asc' },
              include: {
                video: true,
                sourceReferences: true,
                readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { theme: { select: { id: true, slug: true, name: true } } } },
              },
            },
          },
        },
      },
    })
  })

  return { success: true, program, warnings }
}
