/**
 * Loads a `content-export` bundle into the new tables (text-activity SPEC "Export and import", D38).
 * Safe to re-run: activities upsert by `activityKey`. An activity whose current hash differs from the hash
 * recorded at the previous import was edited in the new model; it is kept and reported as a conflict.
 * The recorded hashes live in a JSON ledger the import writes beside the bundle (`import-ledger.json`).
 *
 * Usage: DATABASE_URL=<target> npx tsx scripts/content-import.ts --bundle <bundle.json> [--confirm-production]
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { Prisma, PrismaClient } from '../src/generated/prisma/index.js'
import { estimateDocumentSeconds, hashLessonContent, parseActivityDocument } from '../src/services/activity-document.js'
import { syncActivityMediaUsage } from '../src/services/content-media.service.js'
import { assertDatabaseAllowed, type ConvertedActivity } from './content-convert.js'
import type { Bundle, BundleLesson, BundleProgram } from './content-export.js'

export interface ImportResult {
  created: number
  updated: number
  /** `activityKey`s kept as they are because the new model changed them since the last import (D38). */
  conflicts: string[]
  /** Things the bundle names that the target database lacks (a missing program, an invalid document). */
  skipped: string[]
  /** Things the operator should read before trusting the run (e.g. a missing ledger on a re-run). */
  warnings: string[]
}

interface Ledger {
  /** `<lessonId>|<DRAFT|PUBLISHED>|<activityKey>` -> hash of the content last imported. */
  activities: Record<string, string>
  /** Lessons whose draft was imported once: a draft the leader has since published is not recreated. */
  drafts: Record<string, true>
}

type Tx = Prisma.TransactionClient

const activityHash = (a: { activityKey: string; kind: string; title: string; document: unknown }) =>
  hashLessonContent({ title: '', activities: [{ activityKey: a.activityKey, position: 0, kind: a.kind, title: a.title, document: a.document }] })

function readLedger(path: string): Ledger {
  if (!existsSync(path)) return { activities: {}, drafts: {} }
  return JSON.parse(readFileSync(path, 'utf8'))
}

async function durationOf(tx: Tx, activity: ConvertedActivity): Promise<number | null> {
  const videoId = activity.document.content?.videoId
  if (!videoId) return estimateDocumentSeconds(activity.document)
  const video = await tx.video.findUnique({ where: { id: videoId }, select: { duration: true } })
  return video?.duration ?? null
}

/** Upserts `incoming` into one lesson version by `activityKey`, applying D38's rule. */
async function upsertActivities(
  tx: Tx, versionId: string, lessonId: string, status: 'DRAFT' | 'PUBLISHED', incoming: ConvertedActivity[],
  ledger: Ledger, result: ImportResult,
): Promise<void> {
  const rows = await tx.contentActivity.findMany({ where: { lessonVersionId: versionId } })
  const byKey = new Map(rows.map((r) => [r.activityKey, r]))
  let nextPosition = rows.reduce((max, r) => Math.max(max, r.position), 0) + 1
  const taken = new Set(rows.map((r) => r.position))

  for (const [index, activity] of incoming.entries()) {
    const ledgerKey = `${lessonId}|${status}|${activity.activityKey}`
    const incomingHash = activityHash(activity)
    const existing = byKey.get(activity.activityKey)
    if (!existing) {
      if (ledger.activities[ledgerKey]) {
        // Imported before, gone now: the leader deleted it. Keep the deletion and say so.
        result.conflicts.push(activity.activityKey)
        continue
      }
      const wanted = index + 1
      const position = taken.has(wanted) ? nextPosition : wanted
      taken.add(position)
      nextPosition = Math.max(nextPosition, position + 1)
      await tx.contentActivity.create({
        data: {
          lessonVersionId: versionId, activityKey: activity.activityKey, position, kind: activity.kind, title: activity.title,
          document: activity.document as Prisma.InputJsonValue, estimatedSeconds: await durationOf(tx, activity),
        },
      })
      ledger.activities[ledgerKey] = incomingHash
      result.created++
      continue
    }
    const currentHash = activityHash(existing as any)
    if (currentHash === incomingHash) {
      ledger.activities[ledgerKey] = incomingHash
    } else if (ledger.activities[ledgerKey] === currentHash) {
      await tx.contentActivity.update({
        where: { id: existing.id },
        data: {
          kind: activity.kind, title: activity.title, document: activity.document as Prisma.InputJsonValue,
          estimatedSeconds: await durationOf(tx, activity),
        },
      })
      ledger.activities[ledgerKey] = incomingHash
      result.updated++
    } else {
      result.conflicts.push(activity.activityKey)
    }
  }
}

async function refreshVersion(tx: Tx, versionId: string, title: string): Promise<void> {
  const activities = await tx.contentActivity.findMany({ where: { lessonVersionId: versionId }, orderBy: { position: 'asc' } })
  const seconds = activities.reduce((n, a) => n + (a.estimatedSeconds ?? 0), 0)
  await tx.lessonVersion.update({
    where: { id: versionId },
    data: { contentHash: hashLessonContent({ title, activities }), estimatedSeconds: seconds || null },
  })
  for (const key of new Set(activities.map((a) => a.activityKey))) await syncActivityMediaUsage(tx, key)
}

async function importLesson(
  tx: Tx, program: BundleProgram, lesson: BundleLesson, ledger: Ledger, result: ImportResult,
): Promise<{ publishedVersionId: string | null }> {
  const row = await tx.lesson.findUnique({ where: { id: lesson.id }, select: { id: true, programId: true } })
  if (!row) {
    result.skipped.push(`lesson ${lesson.id}: not in the target database`)
    return { publishedVersionId: null }
  }
  if (row.programId === null) {
    await tx.lesson.update({ where: { id: lesson.id }, data: { programId: program.id, position: lesson.position } })
  }

  let publishedVersionId: string | null = null
  if (lesson.published) {
    const found = await tx.lessonVersion.findFirst({ where: { lessonId: lesson.id, enrollmentId: null, status: 'PUBLISHED', number: 1 } })
    const published = found ?? await tx.lessonVersion.create({
      data: {
        lessonId: lesson.id, number: 1, status: 'PUBLISHED', title: lesson.title,
        publishedAt: program.publishedAt ? new Date(program.publishedAt) : new Date(), publishedById: program.publishedById,
      },
    })
    publishedVersionId = published.id
    await upsertActivities(tx, published.id, lesson.id, 'PUBLISHED', lesson.published, ledger, result)
    await refreshVersion(tx, published.id, lesson.title)
  }

  if (lesson.draft) {
    let draft = await tx.lessonVersion.findFirst({ where: { lessonId: lesson.id, enrollmentId: null, status: 'DRAFT' } })
    if (!draft && !ledger.drafts[lesson.id]) {
      const top = await tx.lessonVersion.findFirst({ where: { lessonId: lesson.id, enrollmentId: null }, orderBy: { number: 'desc' }, select: { number: true } })
      draft = await tx.lessonVersion.create({
        data: { lessonId: lesson.id, number: (top?.number ?? 0) + 1, status: 'DRAFT', title: lesson.title, basedOnVersionId: publishedVersionId },
      })
    }
    if (draft) {
      ledger.drafts[lesson.id] = true
      await upsertActivities(tx, draft.id, lesson.id, 'DRAFT', lesson.draft, ledger, result)
      await refreshVersion(tx, draft.id, draft.title ?? lesson.title)
    }
  }
  return { publishedVersionId }
}

async function importProgram(tx: Tx, program: BundleProgram, ledger: Ledger, result: ImportResult): Promise<void> {
  const row = await tx.studyProgram.findUnique({ where: { id: program.id }, select: { id: true, currentVersionId: true } })
  if (!row) {
    result.skipped.push(`program ${program.id}: not in the target database`)
    return
  }
  const published: { lessonId: string; lessonVersionId: string; position: number }[] = []
  for (const lesson of program.lessons) {
    const { publishedVersionId } = await importLesson(tx, program, lesson, ledger, result)
    if (publishedVersionId) published.push({ lessonId: lesson.id, lessonVersionId: publishedVersionId, position: lesson.position })
  }
  if (!published.length) return
  const version = (await tx.programVersion.findUnique({ where: { programId_number: { programId: program.id, number: 1 } } })) ??
    await tx.programVersion.create({
      data: {
        programId: program.id, number: 1, publishedAt: program.publishedAt ? new Date(program.publishedAt) : new Date(),
        publishedById: program.publishedById,
      },
    })
  await tx.programVersionLesson.createMany({
    data: published.map((p) => ({ programVersionId: version.id, ...p })), skipDuplicates: true,
  })
  if (!row.currentVersionId) await tx.studyProgram.update({ where: { id: program.id }, data: { currentVersionId: version.id } })
}

export async function runImport(
  databaseUrl: string, bundlePath: string, opts: { confirmProduction?: boolean; ledgerPath?: string },
): Promise<ImportResult> {
  assertDatabaseAllowed(databaseUrl, opts)
  const bundle: Bundle = JSON.parse(readFileSync(bundlePath, 'utf8'))
  const ledgerPath = opts.ledgerPath ?? join(dirname(bundlePath), 'import-ledger.json')
  const ledgerExisted = existsSync(ledgerPath)
  const ledger = readLedger(ledgerPath)
  const result: ImportResult = { created: 0, updated: 0, conflicts: [], skipped: [], warnings: [] }

  // A document that no longer validates is a bundle problem, not something to store.
  for (const program of bundle.programs) for (const lesson of program.lessons) {
    for (const side of ['published', 'draft'] as const) {
      lesson[side] = (lesson[side] ?? null) && lesson[side]!.filter((a) => {
        const ok = parseActivityDocument(a.document, a.kind).ok
        if (!ok) result.skipped.push(`activity ${a.activityKey}: document does not validate`)
        return ok
      })
    }
  }

  const prisma = new PrismaClient({ datasourceUrl: databaseUrl })
  try {
    for (const m of bundle.media) {
      const have = (await prisma.media.findUnique({ where: { id: m.id } })) ?? (await prisma.media.findFirst({ where: { url: m.url } }))
      if (have) continue
      await prisma.media.create({
        data: {
          id: m.id, title: m.title, url: m.url, type: 'photo', organizationId: m.organizationId, uploadedBy: m.uploadedBy,
          visibility: 'members', source: 'import',
        },
      })
    }
    if (!ledgerExisted && bundle.programs.length) {
      const have = await prisma.studyProgram.count({ where: { id: { in: bundle.programs.map((p) => p.id) }, currentVersionId: { not: null } } })
      if (have) {
        result.warnings.push(
          `no ledger at ${ledgerPath} but ${have} target program(s) are already imported: every changed activity will be reported as a conflict. ` +
          'Re-export into the first export directory, or pass --ledger <path to the first import-ledger.json>.')
      }
    }
    for (const program of bundle.programs) {
      await prisma.$transaction((tx) => importProgram(tx, program, ledger, result), { timeout: 120_000, maxWait: 30_000 })
    }
    for (const t of bundle.templateActivities) {
      const done = await prisma.lessonTemplateActivity.updateMany({
        where: { id: t.id, kind: null }, data: { kind: t.kind, document: t.document as Prisma.InputJsonValue },
      })
      result.updated += done.count
    }
  } finally {
    await prisma.$disconnect()
  }

  writeFileSync(ledgerPath, JSON.stringify(ledger, null, 2))
  const lines = ['# Content import report', '', `Created ${result.created}, updated ${result.updated}.`, '', '## Conflicts (D38)', '']
  lines.push(...(result.conflicts.length
    ? ['Kept as edited in the new model; the export differs.', ...result.conflicts.map((k) => `- ${k}`)]
    : ['None.']))
  if (result.warnings.length) lines.push('', '## Warnings', '', ...result.warnings.map((w) => `- ${w}`))
  lines.push('', '## Skipped', '', ...(result.skipped.length ? result.skipped.map((s) => `- ${s}`) : ['None.']), '')
  writeFileSync(join(dirname(ledgerPath), 'import-report.md'), lines.join('\n'))
  return result
}

// ---- CLI ---------------------------------------------------------------------------------------------------------

if (process.argv[1]?.endsWith('content-import.ts')) {
  const args = process.argv.slice(2)
  const at = args.indexOf('--bundle')
  const bundle = at >= 0 ? args[at + 1] : undefined
  const ledgerAt = args.indexOf('--ledger')
  const ledger = ledgerAt >= 0 ? args[ledgerAt + 1] : undefined
  const url = process.env.DATABASE_URL
  if (!url || !bundle) {
    console.error('Usage: DATABASE_URL=<target> npx tsx scripts/content-import.ts --bundle <bundle.json> [--ledger <import-ledger.json>] [--confirm-production]')
    process.exit(1)
  }
  runImport(url, resolve(bundle), { confirmProduction: args.includes('--confirm-production'), ledgerPath: ledger ? resolve(ledger) : undefined })
    .then((r) => {
      console.log(`created ${r.created}, updated ${r.updated}, conflicts ${r.conflicts.length}, skipped ${r.skipped.length}`)
      for (const w of r.warnings) console.warn(`WARNING: ${w}`)
      for (const k of r.conflicts) console.log(`conflict: ${k}`)
    })
    .catch((e) => { console.error(e.message); process.exit(1) })
}
