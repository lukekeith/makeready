/**
 * Backfill Read highlights from ActivityReadBlock.selections into content_highlights.
 *
 * Feature: docs/features/highlighting/ phase 3 (12-phase-3-server-backfill.md).
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────────
 * THIS FILE IS CURRENTLY READ-ONLY. There is no `--apply` path yet, deliberately.
 *
 * The write half is blocked on a decision (09 §X-l): the backfill cannot be hash-neutral, and the
 * agreed repair — re-stamping the stored hash baselines — turns out to need a published-version
 * *audit record* rewritten too. That is a judgement call, not an implementation detail, so nothing
 * here writes until it is answered.
 *
 * What this does today is the whole pre-flight (tasks 3.2 and 3.4), which is useful regardless of
 * how that decision goes: it proves whether `selections` can be reproduced byte-for-byte, and it
 * measures exactly how many stored baselines are re-stampable versus already genuinely drifted.
 * ─────────────────────────────────────────────────────────────────────────────────────────────
 *
 * Usage:  npx tsx scripts/backfill-highlights.ts [--verbose]
 */

import { prisma } from '../src/lib/prisma'
import { hashLessonContent, LESSON_CONTENT_INCLUDE } from '../src/services/lesson-content-hash'

const VERBOSE = process.argv.includes('--verbose')

if (process.argv.includes('--apply')) {
  console.error('--apply is not implemented yet: the write path is blocked on 09 §X-l.')
  process.exit(2)
}

interface Span { start: number; end: number; style?: string }

/** The projection syncSelectionsForBlock would regenerate from rows created by this backfill. */
function projectionFor(spans: Span[]): Array<{ start: number; end: number; style: string }> {
  // orderNumber = index in the existing array (12 §3.3), so an orderNumber-sorted projection
  // re-emits the original order. Keys are exactly start/end/style, matching the client encoder.
  return spans.map((s) => ({ start: s.start, end: s.end, style: s.style ?? 'highlight' }))
}

async function main() {
  console.log('\n═══ backfill-highlights — DRY RUN (read-only; no --apply path exists yet) ═══\n')

  // ── Candidates: blocks whose highlights still live only in the selections column ──────────
  const blocks = await prisma.activityReadBlock.findMany({
    select: { id: true, selections: true, lessonActivityId: true, scheduledActivityId: true },
  })

  const candidates = blocks.filter((b) => {
    if (!Array.isArray(b.selections) || b.selections.length === 0) return false
    return true
  })

  const rowCounts = new Map<string, number>()
  for (const group of await prisma.contentHighlight.groupBy({
    by: ['readBlockId'],
    _count: { _all: true },
  })) {
    rowCounts.set(group.readBlockId, group._count._all)
  }

  const toMigrate = candidates.filter((b) => (rowCounts.get(b.id) ?? 0) === 0)

  console.log(`Blocks with a non-empty selections array : ${candidates.length}`)
  console.log(`  …already having rows (skip, idempotent): ${candidates.length - toMigrate.length}`)
  console.log(`  …to migrate                            : ${toMigrate.length}`)
  console.log(`  spans to create                        : ${toMigrate.reduce((n, b) => n + (b.selections as Span[]).length, 0)}`)

  // ── Pre-flight 1: would `selections` survive byte-for-byte? (task 3.2) ────────────────────
  const dirty: string[] = []
  const dupes: string[] = []
  for (const b of toMigrate) {
    const spans = b.selections as Span[]
    // Compare element-wise on (start, end, style) in array order — NOT raw JSON.stringify.
    // Postgres `jsonb` normalises key order on write ({start,end,style} is stored as
    // {end,start,style}), so key order is not something this backfill can change or preserve;
    // comparing stringified key order measures a storage artifact, not a real difference.
    // Array order and values ARE ours to preserve, and are what this checks.
    const after = projectionFor(spans)
    const same =
      spans.length === after.length &&
      spans.every((s, i) =>
        s.start === after[i].start && s.end === after[i].end && (s.style ?? 'highlight') === after[i].style)
    if (!same) {
      dirty.push(`${b.id}\n      before=${JSON.stringify(spans)}\n      after =${JSON.stringify(after)}`)
    }

    // (readBlockId, start, end) is UNIQUE — exact duplicate spans in one array cannot both insert.
    const seen = new Set<string>()
    for (const s of spans) {
      const key = `${s.start}:${s.end}`
      if (seen.has(key)) { dupes.push(`${b.id} has a duplicate span ${key}`); break }
      seen.add(key)
    }
  }

  console.log(`\n── Pre-flight 1 · selections byte-identity ──`)
  console.log(dirty.length === 0
    ? '  ✅ CLEAN — every block re-serialises identically'
    : `  ⛔ DIRTY — ${dirty.length} block(s) would change. This is a STOP.`)
  if (dirty.length && VERBOSE) dirty.forEach((d) => console.log('    ', d))
  if (dupes.length) {
    console.log(`  ⚠️  ${dupes.length} block(s) contain duplicate (start,end) spans — the unique`)
    console.log('     constraint would reject them; they need de-duplication (12 §3.10).')
    if (VERBOSE) dupes.forEach((d) => console.log('    ', d))
  }

  // ── Pre-flight 2: the hash delta (task 3.4) ───────────────────────────────────────────────
  const activityIds = [...new Set(toMigrate.map((b) => b.lessonActivityId).filter(Boolean) as string[])]
  const activities = await prisma.lessonActivity.findMany({
    where: { id: { in: activityIds } }, select: { id: true, lessonId: true },
  })
  const lessonIds = [...new Set(activities.map((a) => a.lessonId))]
  const lessons = await prisma.lesson.findMany({
    where: { id: { in: lessonIds } }, include: LESSON_CONTENT_INCLUDE,
  })

  const spansByBlock = new Map(toMigrate.map((b) => [b.id, b.selections as Span[]]))
  const hashDelta = new Map<string, { before: string; after: string }>()

  for (const lesson of lessons) {
    const before = hashLessonContent(lesson as never)
    // Simulate exactly what the apply step would create.
    for (const activity of lesson.activities ?? []) {
      for (const block of (activity as { readBlocks?: Array<Record<string, unknown>> }).readBlocks ?? []) {
        const spans = spansByBlock.get(block.id as string)
        if (!spans) continue
        block.contentHighlights = spans.map((s, i) => ({
          orderNumber: i, start: s.start, end: s.end, noteMarkdown: '', style: s.style ?? 'highlight',
        }))
      }
    }
    const after = hashLessonContent(lesson as never)
    if (before !== after) hashDelta.set(lesson.id, { before, after })
  }

  console.log(`\n── Pre-flight 2 · lesson content hash delta ──`)
  console.log(`  lessons touched            : ${lessons.length}`)
  console.log(`  …whose hash MOVES          : ${hashDelta.size}`)
  console.log('  (moving is expected and unavoidable — 09 §X-k. What matters is the split below.)')

  // Where is each moved lesson's OLD hash still recorded? Those are re-stampable. Anything
  // recording something else was already genuinely drifted and must be left alone.
  let schedMatch = 0, schedDrifted = 0
  const scheduleVersions = await prisma.lessonScheduleVersion.findMany({
    where: { sourceContentHash: { not: null } },
    select: { id: true, sourceContentHash: true, lessonSchedule: { select: { lessonId: true } } },
  })
  for (const v of scheduleVersions) {
    const d = v.lessonSchedule?.lessonId ? hashDelta.get(v.lessonSchedule.lessonId) : undefined
    if (!d) continue
    if (v.sourceContentHash === d.before) schedMatch++
    else schedDrifted++
  }

  let snapMatch = 0, snapDrifted = 0, mapMatch = 0, mapDrifted = 0
  const programVersions = await prisma.studyProgramVersion.findMany({
    select: { id: true, lessonHashes: true, snapshot: true },
  })
  for (const pv of programVersions) {
    const snapLessons = ((pv.snapshot as { lessons?: Array<{ id: string; contentHash: string }> })?.lessons) ?? []
    for (const sl of snapLessons) {
      const d = hashDelta.get(sl.id)
      if (!d) continue
      if (sl.contentHash === d.before) snapMatch++
      else snapDrifted++
    }
    const map = (pv.lessonHashes ?? {}) as Record<string, string>
    for (const [lessonId, h] of Object.entries(map)) {
      const d = hashDelta.get(lessonId)
      if (!d) continue
      if (h === d.before) mapMatch++
      else mapDrifted++
    }
  }

  console.log(`\n── Where the OLD hash is still recorded (the re-stamp surface) ──`)
  console.log(`  LessonScheduleVersion.sourceContentHash   : ${schedMatch} re-stampable · ${schedDrifted} already drifted`)
  console.log(`  StudyProgramVersion.snapshot[].contentHash: ${snapMatch} re-stampable · ${snapDrifted} already drifted`)
  console.log(`  StudyProgramVersion.lessonHashes[lessonId]: ${mapMatch} re-stampable · ${mapDrifted} already drifted`)
  console.log('\n  "already drifted" = that lesson was genuinely edited after the baseline was')
  console.log('  recorded. Those MUST be left alone; re-stamping them would mark a real edit as synced.')
  console.log('\n═══ end of dry run — nothing was written ═══\n')

  await prisma.$disconnect()
}

main().catch(async (error) => {
  console.error(error)
  await prisma.$disconnect()
  process.exit(1)
})
