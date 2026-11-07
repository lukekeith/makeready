/**
 * The one-time content export (text-activity SPEC "Export and import", 05 s6): reads a dump restored to a
 * scratch database (the old tables) and writes `bundle.json` plus a reviewable `report.md`. Never reads
 * production unless `--confirm-production` is passed.
 *
 * Usage: DATABASE_URL=<restored dump> npx tsx scripts/content-export.ts --out <dir> [--confirm-production]
 */
import { mkdirSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { PrismaClient } from '../src/generated/prisma/index.js'
import { hashLessonContent, parseActivityDocument } from '../src/services/activity-document.js'
import {
  assertDatabaseAllowed, convertActivity, deterministicMediaId,
  type ConvertedActivity, type OldActivity, type OldBlock,
} from './content-convert.js'

export interface BundleLesson {
  id: string
  position: number
  title: string
  published: ConvertedActivity[] | null
  draft: ConvertedActivity[] | null
}

export interface BundleProgram {
  id: string
  name: string
  publishedAt: string | null
  publishedById: string | null
  lessons: BundleLesson[]
}

export interface BundleMedia { id: string; url: string; organizationId: string; uploadedBy: string; title: string }
export interface BundleTemplateActivity { id: string; kind: string; document: Record<string, any> }

export interface Bundle {
  formatVersion: 1
  exportedAt: string
  programs: BundleProgram[]
  media: BundleMedia[]
  templateActivities: BundleTemplateActivity[]
}

export interface ExportResult { bundlePath: string; reportPath: string; bundle: Bundle; report: string }

const ACTIVITY_INCLUDE = {
  sourceReferences: true,
  readBlocks: { orderBy: { orderNumber: 'asc' as const }, include: { contentHighlights: { orderBy: { orderNumber: 'asc' as const } } } },
} as const

function oldFromRow(a: any): OldActivity {
  return {
    id: a.id, activityType: a.activityType, orderNumber: a.orderNumber, title: a.title, helpTitle: a.helpTitle,
    helpDescription: a.helpDescription, placeholder: a.placeholder, referenceTitle: a.referenceTitle,
    readContent: a.readContent, videoId: a.videoId, youtubeUrl: a.youtubeUrl, youtubeVideoId: a.youtubeVideoId,
    youtubeStartSeconds: a.youtubeStartSeconds, youtubeEndSeconds: a.youtubeEndSeconds, themeId: a.themeId,
    sourceReferences: a.sourceReferences.map((r: any) => ({ ...r })),
    readBlocks: a.readBlocks.map((b: any): OldBlock => ({
      id: b.id, orderNumber: b.orderNumber, title: b.title, content: b.content, isLocked: b.isLocked,
      contentFormat: b.contentFormat, sourceReferenceId: b.sourceReferenceId, themeId: b.themeId,
      backgroundImageUrl: b.backgroundImageUrl, backgroundColor: b.backgroundColor,
      backgroundOverlayOpacity: b.backgroundOverlayOpacity, fontSize: b.fontSize,
      highlights: b.contentHighlights.map((h: any) => ({
        orderNumber: h.orderNumber, start: h.start, end: h.end, noteMarkdown: h.noteMarkdown, style: h.style,
      })),
    })),
  }
}

/** A published `StudyProgramVersion.snapshot` lesson back into old-row shape; null when it cannot be aligned to ids. */
function oldFromSnapshot(lesson: any): OldActivity[] | null {
  const activities: any[] = lesson?.content?.activities ?? []
  const ids: string[] = lesson?.activityIds ?? []
  if (activities.length && ids.length !== activities.length) return null
  return activities.map((a, i) => oldFromRow({
    ...a, id: ids[i], activityType: a.type,
    sourceReferences: (a.sourceReferences ?? []).map((r: any, n: number) => ({ id: r.id ?? `${ids[i]}:ref${n}`, ...r })),
    readBlocks: (a.readBlocks ?? []).map((b: any, n: number) => ({
      ...b, id: b.id ?? `${ids[i]}:b${n}`,
      contentHighlights: (b.exegesisHighlights ?? []).map((h: any) => ({ style: 'highlight', ...h })),
    })),
  }))
}

const tally = (items: string[]) =>
  Object.entries(items.reduce<Record<string, number>>((m, k) => ((m[k] = (m[k] ?? 0) + 1), m), {}))
    .sort(([a], [b]) => (a < b ? -1 : 1))
    .map(([k, n]) => `${k} ${n}`)
    .join(', ') || 'none'

interface ProgramReport {
  name: string
  id: string
  oldTypes: string[]
  newKinds: string[]
  losses: string[]
  unresolved: string[]
  note: string[]
}

export async function runExport(
  databaseUrl: string, outDir: string, opts: { confirmProduction?: boolean },
): Promise<ExportResult> {
  assertDatabaseAllowed(databaseUrl, opts)
  const prisma = new PrismaClient({ datasourceUrl: databaseUrl })
  try {
    const programs = await prisma.studyProgram.findMany({
      orderBy: { createdAt: 'asc' },
      include: {
        lessons: { orderBy: { dayNumber: 'asc' }, include: { activities: { orderBy: { orderNumber: 'asc' }, include: ACTIVITY_INCLUDE } } },
        versions: { orderBy: { versionNumber: 'desc' }, take: 1 },
      },
    })

    const urls = new Set<string>()
    for (const p of programs) for (const l of p.lessons) for (const a of l.activities) for (const b of a.readBlocks) {
      if (b.backgroundImageUrl) urls.add(b.backgroundImageUrl)
    }
    const existing = await prisma.media.findMany({ where: { url: { in: [...urls] } }, select: { id: true, url: true } })
    const mediaByUrl = new Map(existing.map((m) => [m.url, m.id]))
    const videoIds = new Set<string>()
    const bundleMedia = new Map<string, BundleMedia>()
    const reports: ProgramReport[] = []

    const bundlePrograms: BundleProgram[] = []
    for (const program of programs) {
      const report: ProgramReport = { name: program.name, id: program.id, oldTypes: [], newKinds: [], losses: [], unresolved: [], note: [] }
      const ctx = {
        mediaIdForUrl: (url: string) => {
          const found = mediaByUrl.get(url)
          if (found) return found
          if (!program.organizationId) {
            report.unresolved.push(`background image ${url}: program has no organization to own a Media row`)
            return undefined
          }
          const id = deterministicMediaId(url)
          bundleMedia.set(id, { id, url, organizationId: program.organizationId, uploadedBy: program.creatorId, title: 'Imported background' })
          return id
        },
      }
      const convert = (olds: OldActivity[], count: boolean) => {
        const out: ConvertedActivity[] = []
        for (const old of olds) {
          const r = convertActivity(old, ctx)
          if (count) report.oldTypes.push(old.activityType)
          for (const a of r.activities) {
            const parsed = parseActivityDocument(a.document, a.kind)
            if (!parsed.ok) {
              report.losses.push(`activity ${a.activityKey} dropped: ${parsed.error}`)
              continue
            }
            if (count) report.newKinds.push(a.kind)
            if (a.document.content?.videoId) videoIds.add(a.document.content.videoId)
            out.push(a)
          }
          if (count) report.losses.push(...r.losses)
        }
        return out
      }

      const latest = program.versions[0]
      const snapshotLessons = new Map<string, any>(((latest?.snapshot as any)?.lessons ?? []).map((l: any) => [l.id, l]))
      const livePublished = !latest && program.isPublished
      const bundleLessons: BundleLesson[] = []
      for (const lesson of program.lessons) {
        const title = lesson.title ?? `Day ${lesson.dayNumber}`
        const live = convert(lesson.activities.map(oldFromRow), true)
        let published: ConvertedActivity[] | null = null
        if (livePublished) published = live
        else if (latest && snapshotLessons.has(lesson.id)) {
          const snap = oldFromSnapshot(snapshotLessons.get(lesson.id))
          if (snap) published = convert(snap, false)
          else {
            report.note.push(`lesson ${lesson.id}: snapshot has no activity ids; live content imported as published`)
            published = live
          }
        }
        const same = published !== null &&
          hashLessonContent({ title, activities: published.map((a, position) => ({ ...a, position })) }) ===
          hashLessonContent({ title, activities: live.map((a, position) => ({ ...a, position })) })
        const draft = livePublished || same ? null : live
        bundleLessons.push({ id: lesson.id, position: lesson.dayNumber ?? bundleLessons.length + 1, title, published, draft })
        if (draft && published) report.note.push(`lesson ${lesson.id}: unpublished edits become its draft`)
      }
      for (const id of snapshotLessons.keys()) {
        if (!program.lessons.some((l) => l.id === id)) report.note.push(`lesson ${id}: in the published snapshot but deleted since; not imported`)
      }
      const hasPublished = bundleLessons.some((l) => l.published)
      bundlePrograms.push({
        id: program.id, name: program.name,
        publishedAt: hasPublished ? (latest?.publishedAt ?? program.publishedAt)?.toISOString() ?? null : null,
        publishedById: latest?.publishedById ?? null,
        lessons: bundleLessons,
      })
      reports.push(report)
    }

    if (videoIds.size) {
      const found = await prisma.video.findMany({ where: { id: { in: [...videoIds] } }, select: { id: true } })
      const have = new Set(found.map((v) => v.id))
      for (const report of reports) {
        const program = bundlePrograms.find((p) => p.id === report.id)!
        for (const l of program.lessons) for (const a of [...(l.published ?? []), ...(l.draft ?? [])]) {
          const id = a.document.content?.videoId
          if (id && !have.has(id)) report.unresolved.push(`activity ${a.activityKey}: Video ${id} does not exist`)
        }
      }
    }

    const templates = await prisma.lessonTemplateActivity.findMany({ where: { type: { not: null } }, orderBy: { id: 'asc' } })
    const templateActivities: BundleTemplateActivity[] = []
    const templateLosses: string[] = []
    for (const t of templates) {
      const r = convertActivity({
        id: t.id, activityType: t.type!, orderNumber: t.orderNumber, title: t.title, helpTitle: t.helpTitle,
        helpDescription: t.helpDescription, placeholder: t.placeholder, referenceTitle: t.referenceTitle,
        readBlocks: [], sourceReferences: [],
      })
      const first = r.activities[0]
      if (first && parseActivityDocument(first.document, first.kind).ok) {
        templateActivities.push({ id: t.id, kind: first.kind, document: first.document })
      }
      templateLosses.push(...r.losses)
    }

    const bundle: Bundle = {
      formatVersion: 1, exportedAt: new Date().toISOString(), programs: bundlePrograms,
      media: [...bundleMedia.values()], templateActivities,
    }

    const lines = ['# Content export report', '', `Exported ${bundle.exportedAt}.`, '',
      `${bundlePrograms.length} programs, ${bundlePrograms.reduce((n, p) => n + p.lessons.length, 0)} lessons, ` +
      `${bundle.media.length} media rows to register, ${templateActivities.length} template activities.`, '']
    for (const r of reports) {
      lines.push(`## ${r.name} (${r.id})`, '', `- Old types: ${tally(r.oldTypes)}`, `- New kinds: ${tally(r.newKinds)}`)
      const section = (label: string, items: string[]) => {
        lines.push(`- ${label}: ${items.length ? '' : 'none'}`)
        for (const item of items) lines.push(`  - ${item}`)
      }
      section('Converted with loss', r.losses)
      section('Unresolved references', r.unresolved)
      section('Notes', r.note)
      lines.push('')
    }
    lines.push('## Templates', '', `- Converted with loss: ${templateLosses.length ? '' : 'none'}`)
    for (const l of templateLosses) lines.push(`  - ${l}`)
    lines.push('', '## Conflicts', '', 'Conflicts (an activity edited in the new model since the last import) are listed by the import, in `import-report.md` beside this file.', '')
    const report = lines.join('\n')

    mkdirSync(outDir, { recursive: true })
    const bundlePath = join(outDir, 'bundle.json')
    const reportPath = join(outDir, 'report.md')
    writeFileSync(bundlePath, JSON.stringify(bundle, null, 2))
    writeFileSync(reportPath, report)
    return { bundlePath, reportPath, bundle, report }
  } finally {
    await prisma.$disconnect()
  }
}

// ---- CLI ---------------------------------------------------------------------------------------------------------

if (process.argv[1]?.endsWith('content-export.ts')) {
  const args = process.argv.slice(2)
  const outIndex = args.indexOf('--out')
  const out = outIndex >= 0 ? args[outIndex + 1] : undefined
  const url = process.env.DATABASE_URL
  if (!url || !out) {
    console.error('Usage: DATABASE_URL=<restored dump> npx tsx scripts/content-export.ts --out <dir> [--confirm-production]')
    process.exit(1)
  }
  runExport(url, resolve(out), { confirmProduction: args.includes('--confirm-production') })
    .then((r) => console.log(`Wrote ${r.bundlePath} and ${r.reportPath}`))
    .catch((e) => { console.error(e.message); process.exit(1) })
}
