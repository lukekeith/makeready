/**
 * text-activity D43: the program export file, format `version: 2`, on lesson versions and activity documents.
 *
 * The file is a ZIP holding `manifest.json` (a `ProgramExportV2`). Export writes each live lesson's draft when
 * one exists, else its latest published version (D43). Import makes a new program whose lessons each get a DRAFT
 * numbered 1 with new `activityKey`s, every document validated and media-checked as a POST would (D3, D34).
 * A `version: 1` file is refused (D1).
 */
import { randomUUID } from 'node:crypto'
import { z } from 'zod'
import archiver from 'archiver'
import AdmZip from 'adm-zip'
import { PassThrough } from 'stream'
import type { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { ACTIVITY_KINDS, documentMediaRefs, estimateDocumentSeconds, parseActivityDocument } from './activity-document.js'
import { ContentError } from './content-errors.js'
import { assertDocumentMediaAllowed, syncActivityMediaUsage } from './content-media.service.js'
import { sumEstimatedSeconds } from './lesson-estimate.service.js'
import { canManageOrgContent } from './permission.js'
import { loadProgramPayload } from './program-lessons.service.js'

export interface ProgramExportV2 {
  version: 2
  program: {
    title: string
    description: string | null
    coverImageUrl: string | null
    requireResponse: boolean
  }
  lessons: {
    position: number
    title: string | null
    activities: { kind: string; title: string; document: unknown }[]
  }[]
}

const manifestSchema = z.object({
  version: z.literal(2),
  program: z.object({
    title: z.string().trim().min(1).max(200),
    description: z.string().nullable().optional(),
    coverImageUrl: z.string().nullable().optional(),
    requireResponse: z.boolean().default(true),
  }),
  lessons: z.array(z.object({
    position: z.number().int(),
    title: z.string().nullable().optional(),
    activities: z.array(z.object({
      kind: z.enum(ACTIVITY_KINDS),
      title: z.string(),
      document: z.record(z.unknown()),
    })),
  })),
})

export interface ExportResult {
  success: boolean
  buffer?: Buffer
  filename?: string
  error?: string
}

export interface ImportResult {
  success: boolean
  program?: any
  warnings?: string[]
  error?: string
  code?: 'VALIDATION' | 'TOO_LARGE'
  status?: number
}

// ============================================================================
// Export
// ============================================================================

/** The version the file carries for a lesson: its program draft, else its latest published program version. */
async function exportedVersion(lessonId: string) {
  const include = { activities: { orderBy: { position: 'asc' as const } } }
  const draft = await prisma.lessonVersion.findFirst({ where: { lessonId, enrollmentId: null, status: 'DRAFT' }, include })
  if (draft) return draft
  return prisma.lessonVersion.findFirst({
    where: { lessonId, enrollmentId: null, status: 'PUBLISHED' },
    orderBy: { number: 'desc' },
    include,
  })
}

export async function exportProgram(programId: string, userId: string): Promise<ExportResult> {
  const program = await prisma.studyProgram.findFirst({ where: { id: programId, isActive: true } })
  if (!program || !(await canManageOrgContent(userId, program.organizationId, program.creatorId))) {
    return { success: false, error: 'Program not found' }
  }

  const lessons = await prisma.lesson.findMany({ where: { programId, deletedAt: null }, orderBy: { position: 'asc' } })
  const file: ProgramExportV2 = {
    version: 2,
    program: {
      title: program.name,
      description: program.description,
      coverImageUrl: program.coverImageUrl,
      requireResponse: program.requireResponse,
    },
    lessons: [],
  }
  for (const lesson of lessons) {
    const version = await exportedVersion(lesson.id)
    file.lessons.push({
      position: lesson.position ?? file.lessons.length + 1,
      title: version?.title ?? null,
      activities: (version?.activities ?? []).map((a) => ({ kind: a.kind, title: a.title, document: a.document })),
    })
  }

  const buffer = await createZipBuffer(file)
  const slug = program.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
  return { success: true, buffer, filename: `program-export-${slug}.zip` }
}

async function createZipBuffer(file: ProgramExportV2): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = []
    const passthrough = new PassThrough()

    passthrough.on('data', (chunk: Buffer) => chunks.push(chunk))
    passthrough.on('end', () => resolve(Buffer.concat(chunks)))
    passthrough.on('error', reject)

    const archive = archiver('zip', { zlib: { level: 9 } })
    archive.on('error', reject)
    archive.pipe(passthrough)
    archive.append(JSON.stringify(file, null, 2), { name: 'manifest.json' })
    archive.finalize()
  })
}

// ============================================================================
// Import
// ============================================================================

interface PreparedLesson {
  title: string | null
  activities: { kind: string; title: string; document: Prisma.InputJsonValue; estimatedSeconds: number | null }[]
}

const invalid = (error: string): ImportResult => ({ success: false, error, code: 'VALIDATION', status: 400 })

export async function importProgram(zipBuffer: Buffer, userId: string): Promise<ImportResult> {
  let manifestEntry
  try {
    manifestEntry = new AdmZip(zipBuffer).getEntry('manifest.json')
  } catch {
    return invalid('File is not a valid ZIP')
  }
  if (!manifestEntry) return invalid('ZIP does not contain manifest.json')

  let raw: any
  try {
    raw = JSON.parse(manifestEntry.getData().toString('utf8'))
  } catch {
    return invalid('manifest.json is not valid JSON')
  }
  if (raw?.version !== 2) return invalid('Unsupported export version')

  const parsed = manifestSchema.safeParse(raw)
  if (!parsed.success) {
    return invalid(`Invalid manifest: ${parsed.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join('; ')}`)
  }
  const manifest = parsed.data

  // Every document is validated as a POST would, and its media checked, before anything is written.
  const lessons = [...manifest.lessons].sort((a, b) => a.position - b.position)
  const refs = { mediaIds: [] as string[], videoIds: [] as string[] }
  const prepared: PreparedLesson[] = []
  for (const lesson of lessons) {
    const activities: PreparedLesson['activities'] = []
    for (const [index, activity] of lesson.activities.entries()) {
      const checked = parseActivityDocument(activity.document, activity.kind)
      if (!checked.ok) {
        const where = `lessons[position ${lesson.position}].activities[${index}]`
        return { success: false, error: `${where}: ${checked.error}`, code: checked.code, status: checked.code === 'TOO_LARGE' ? 413 : 400 }
      }
      const found = documentMediaRefs(checked.document)
      refs.mediaIds.push(...found.mediaIds)
      refs.videoIds.push(...found.videoIds)
      activities.push({
        kind: activity.kind,
        title: activity.title,
        document: checked.document as Prisma.InputJsonValue,
        estimatedSeconds: estimateDocumentSeconds(checked.document),
      })
    }
    prepared.push({ title: lesson.title ?? null, activities })
  }
  try {
    await assertDocumentMediaAllowed(prisma, userId, refs)
  } catch (err) {
    if (err instanceof ContentError) return invalid(err.message)
    throw err
  }

  const creatorOrg = await prisma.organization.findFirst({ where: { ownerId: userId }, select: { id: true } })

  const programId = await prisma.$transaction(async (tx) => {
    const program = await tx.studyProgram.create({
      data: {
        name: manifest.program.title,
        description: manifest.program.description ?? null,
        days: prepared.length,
        coverImageUrl: manifest.program.coverImageUrl ?? null,
        requireResponse: manifest.program.requireResponse,
        isPublished: false,
        creatorId: userId,
        leaderId: userId,
        organizationId: creatorOrg?.id,
      },
    })
    for (const [index, lesson] of prepared.entries()) {
      const created = await tx.lesson.create({ data: { programId: program.id, position: index + 1 } })
      const rows = lesson.activities.map((a, position) => ({ ...a, activityKey: randomUUID(), position }))
      await tx.lessonVersion.create({
        data: {
          lessonId: created.id,
          number: 1,
          status: 'DRAFT',
          title: lesson.title,
          estimatedSeconds: sumEstimatedSeconds(rows.map((r) => ({ estimatedSeconds: r.estimatedSeconds }))),
          activities: { create: rows },
        },
      })
      for (const row of rows) {
        const found = documentMediaRefs(row.document)
        if (found.mediaIds.length || found.videoIds.length) await syncActivityMediaUsage(tx, row.activityKey)
      }
    }
    return program.id
  }, { timeout: 30_000 })

  const loaded = await loadProgramPayload(programId)
  return { success: true, program: loaded?.program ?? null, warnings: [] }
}
