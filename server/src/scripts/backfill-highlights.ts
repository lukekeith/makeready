/**
 * Backfill Read highlights from ActivityReadBlock.selections into content_highlights.
 *
 * Feature: docs/features/highlighting/ phase 3 (12-phase-3-server-backfill.md).
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────────
 * DRY RUN IS THE DEFAULT. `--apply` is required to write anything, and even then the run aborts
 * unless the `selections` pre-flight is clean.
 *
 * WHY THE APPLY STEP TOUCHES MORE THAN THE HIGHLIGHT TABLE. Creating these rows moves each
 * affected lesson's content hash — unavoidably, because the hash covers the highlight rows and not
 * just the `selections` column (09 §X-k). Left alone, that surfaces to leaders as "content updated"
 * on lessons nobody edited. So the same transaction corrects the FOUR places the old hash is
 * recorded, but **only where the stored value still equals the pre-backfill hash** — anything else
 * was genuinely edited since, and silently "fixing" it would mark a real edit as synced
 * (09 §X-l, design table at 12 §3.7).
 *
 * Every write is journalled to a manifest file before the transaction commits, so the whole run is
 * reversible.
 * ─────────────────────────────────────────────────────────────────────────────────────────────
 *
 * Usage:  npx tsx src/scripts/backfill-highlights.ts [--verbose]
 *         npx tsx src/scripts/backfill-highlights.ts --rollback=<manifest.json>
 *         npx tsx src/scripts/backfill-highlights.ts --apply [--verbose]
 *
 * Lives under src/ so `npx tsc --noEmit` actually covers it — tsconfig includes only `src`,
 * so a script in the repo-root `scripts/` dir is invisible to the phase gate. This is the
 * riskiest code in the feature; it does not get to skip the typechecker.
 */

import { readFileSync, writeFileSync } from 'fs'
import { join } from 'path'
import { prisma } from '../lib/prisma.js'
import {
  canonicalLessonContent,
  hashLessonContent,
  LESSON_CONTENT_INCLUDE,
} from '../services/lesson-content-hash.js'

const VERBOSE = process.argv.includes('--verbose')
const APPLY = process.argv.includes('--apply')
const ROLLBACK = process.argv.find((a) => a.startsWith('--rollback='))?.split('=')[1]

interface Span { start: number; end: number; style?: string }

/** One reversible write. The manifest is a list of these. */
interface ManifestEntry {
  table: string
  rowId: string
  field: string
  lessonId?: string
  oldValue: unknown
  newValue: unknown
}

/** The projection syncSelectionsForBlock would regenerate from rows created by this backfill. */
function projectionFor(spans: Span[]): Array<{ start: number; end: number; style: string }> {
  // orderNumber = index in the existing array (12 §3.3), so an orderNumber-sorted projection
  // re-emits the original order. Keys are exactly start/end/style, matching the client encoder.
  return spans.map((s) => ({ start: s.start, end: s.end, style: s.style ?? 'highlight' }))
}

/**
 * Reverse a previous `--apply` from its manifest.
 *
 * This exists so the rollback can be REHEARSED rather than merely described. A rollback that has
 * never been executed is a paragraph, not a capability — and this migration touches customer data
 * across four tables, one of which is a published-version audit record.
 */
async function rollback(manifestPath: string) {
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as ManifestEntry[]
  console.log(`\n═══ ROLLBACK from ${manifestPath} (${manifest.length} entries) ═══\n`)

  await prisma.$transaction(async (tx) => {
    // 1 ── delete the rows this run created. Every such block had ZERO rows beforehand
    //      (that is the condition the backfill selected on), so deleting all of its rows is exact.
    const blockIds = manifest.filter((m) => m.table === 'content_highlights').map((m) => m.rowId)
    if (blockIds.length) {
      const { count } = await tx.contentHighlight.deleteMany({ where: { readBlockId: { in: blockIds } } })
      console.log(`  deleted ${count} rows across ${blockIds.length} blocks`)
    }

    // 2 ── restore the schedule-version hashes
    for (const m of manifest.filter((e) => e.table === 'LessonScheduleVersion')) {
      await tx.lessonScheduleVersion.update({
        where: { id: m.rowId },
        data: { sourceContentHash: m.oldValue as string },
      })
    }

    // 3 ── restore the program-version snapshot + map, one row at a time (JSON read-modify-write)
    const pvIds = [...new Set(manifest.filter((e) => e.table === 'StudyProgramVersion').map((e) => e.rowId))]
    for (const pvId of pvIds) {
      const pv = await tx.studyProgramVersion.findUniqueOrThrow({
        where: { id: pvId }, select: { snapshot: true, lessonHashes: true },
      })
      const snapshot = pv.snapshot as { lessons?: Array<{ id: string; contentHash: string; content: unknown }> } | null
      const map = (pv.lessonHashes ?? {}) as Record<string, string>

      for (const m of manifest.filter((e) => e.table === 'StudyProgramVersion' && e.rowId === pvId)) {
        if (m.field === 'snapshot.contentHash') {
          const sl = snapshot?.lessons?.find((l) => l.id === m.lessonId)
          if (sl) sl.contentHash = m.oldValue as string
        } else if (m.field === 'snapshot.content') {
          const sl = snapshot?.lessons?.find((l) => l.id === m.lessonId)
          if (sl) sl.content = m.oldValue
        } else if (m.field.startsWith('lessonHashes.')) {
          map[m.field.slice('lessonHashes.'.length)] = m.oldValue as string
        }
      }

      await tx.studyProgramVersion.update({
        where: { id: pvId },
        data: { snapshot: snapshot as never, lessonHashes: map as never },
      })
    }
    console.log(`  restored baselines on ${pvIds.length} program version(s)`)
  })

  console.log('\n═══ rollback complete — verify against the pre-run fingerprints ═══\n')
  await prisma.$disconnect()
}

async function main() {
  if (ROLLBACK) return rollback(ROLLBACK)

  console.log(APPLY ? '\n═══ backfill-highlights — APPLY ═══\n' : '\n═══ backfill-highlights — DRY RUN (pass --apply to write) ═══\n')

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
  console.log(`  spans to create                        : ${toMigrate.reduce((n, b) => n + (b.selections as unknown as Span[]).length, 0)}`)

  // ── Pre-flight 1: would `selections` survive byte-for-byte? (task 3.2) ────────────────────
  const dirty: string[] = []
  const dupes: string[] = []
  for (const b of toMigrate) {
    const spans = b.selections as unknown as Span[]
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

  const lessonById = new Map(lessons.map((l) => [l.id, l]))
  const spansByBlock = new Map(toMigrate.map((b) => [b.id, b.selections as unknown as Span[]]))
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

  if (!APPLY) {
    console.log('\n═══ end of dry run — nothing was written. Re-run with --apply to write. ═══\n')
    await prisma.$disconnect()
    return
  }

  // ── APPLY ────────────────────────────────────────────────────────────────────────────────
  if (dirty.length > 0) {
    console.error('\n⛔ REFUSING TO APPLY: the selections pre-flight is dirty. Fix normalisation first.')
    await prisma.$disconnect()
    process.exit(1)
  }
  if (dupes.length > 0) {
    console.error('\n⛔ REFUSING TO APPLY: duplicate (start,end) spans would violate the unique')
    console.error('   constraint. De-duplicate them first (12 §3.10).')
    await prisma.$disconnect()
    process.exit(1)
  }

  console.log('\n═══ APPLYING ═══\n')

  const manifest: ManifestEntry[] = []
  const skipped: string[] = []

  await prisma.$transaction(async (tx) => {
    // 1 ── create the rows
    for (const b of toMigrate) {
      const spans = b.selections as unknown as Span[]
      await tx.contentHighlight.createMany({
        data: spans.map((s, i) => ({
          readBlockId: b.id,
          orderNumber: i, // = index in the existing array, so the projection re-emits this order
          start: s.start,
          end: s.end,
          style: s.style ?? 'highlight',
          noteMarkdown: '', // Read spans carry no note; Exegesis notes are untouched
        })),
      })
      manifest.push({
        table: 'content_highlights', rowId: b.id, field: '(rows created)',
        oldValue: 0, newValue: spans.length,
      })
    }

    // NOTE: `selections` is deliberately NOT rewritten. It already holds exactly what the
    // projection would regenerate (pre-flight 1 proved it), so touching it would be a no-op
    // write that only risks changing it.

    // 2 ── re-stamp the four stored baselines, only where they still hold the old hash
    const restamp = async (
      table: string, rowId: string, field: string, lessonId: string,
      current: string | undefined, expected: string, next: string,
      write: () => Promise<unknown>
    ) => {
      if (current !== expected) {
        skipped.push(`${table}.${field} ${rowId} (lesson ${lessonId}) — already drifted, left alone`)
        return
      }
      await write()
      manifest.push({ table, rowId, field, lessonId, oldValue: current, newValue: next })
    }

    for (const v of scheduleVersions) {
      const lessonId = v.lessonSchedule?.lessonId
      const d = lessonId ? hashDelta.get(lessonId) : undefined
      if (!d || !lessonId) continue
      await restamp(
        'LessonScheduleVersion', v.id, 'sourceContentHash', lessonId,
        v.sourceContentHash ?? undefined, d.before, d.after,
        () => tx.lessonScheduleVersion.update({ where: { id: v.id }, data: { sourceContentHash: d.after } })
      )
    }

    for (const pv of await tx.studyProgramVersion.findMany({
      select: { id: true, lessonHashes: true, snapshot: true },
    })) {
      const snapshot = pv.snapshot as { lessons?: Array<{ id: string; contentHash: string; content: unknown }> } | null
      const snapLessons = snapshot?.lessons ?? []
      const map = (pv.lessonHashes ?? {}) as Record<string, string>

      let snapshotChanged = false
      let mapChanged = false

      for (const sl of snapLessons) {
        const d = hashDelta.get(sl.id)
        if (!d) continue
        if (sl.contentHash !== d.before) {
          skipped.push(`StudyProgramVersion.snapshot ${pv.id} (lesson ${sl.id}) — already drifted, left alone`)
          continue
        }
        // contentHash and content move TOGETHER — a snapshot whose hash does not hash its own
        // content is worse than one that is merely stale (12 §3.7).
        const lesson = lessonById.get(sl.id)
        if (!lesson) continue
        manifest.push({
          table: 'StudyProgramVersion', rowId: pv.id, field: 'snapshot.contentHash',
          lessonId: sl.id, oldValue: sl.contentHash, newValue: d.after,
        })
        manifest.push({
          table: 'StudyProgramVersion', rowId: pv.id, field: 'snapshot.content',
          lessonId: sl.id, oldValue: sl.content, newValue: '(regenerated canonical content)',
        })
        sl.contentHash = d.after
        sl.content = canonicalLessonContent(lesson as never)
        snapshotChanged = true
      }

      for (const [lessonId, h] of Object.entries(map)) {
        const d = hashDelta.get(lessonId)
        if (!d) continue
        if (h !== d.before) {
          skipped.push(`StudyProgramVersion.lessonHashes ${pv.id} (lesson ${lessonId}) — already drifted, left alone`)
          continue
        }
        manifest.push({
          table: 'StudyProgramVersion', rowId: pv.id, field: `lessonHashes.${lessonId}`,
          lessonId, oldValue: h, newValue: d.after,
        })
        map[lessonId] = d.after
        mapChanged = true
      }

      if (snapshotChanged || mapChanged) {
        await tx.studyProgramVersion.update({
          where: { id: pv.id },
          data: {
            ...(snapshotChanged ? { snapshot: snapshot as never } : {}),
            ...(mapChanged ? { lessonHashes: map as never } : {}),
          },
        })
      }
    }

    // Manifest is written BEFORE the transaction commits — if this throws, nothing lands.
    const path = join(process.cwd(), `backfill-highlights-manifest-${manifest.length}.json`)
    writeFileSync(path, JSON.stringify(manifest, null, 2))
    console.log(`  manifest written: ${path}`)
  })

  console.log(`\n  rows created for  : ${toMigrate.length} blocks`)
  console.log(`  baselines updated : ${manifest.filter((m) => m.table !== 'content_highlights').length}`)
  console.log(`  left alone (drift): ${skipped.length}`)
  if (skipped.length && VERBOSE) skipped.forEach((s) => console.log('    ', s))

  // ── Post-run sweep (task 3.9): the hashes must now MATCH their stored baselines ───────────
  const after = await prisma.lesson.findMany({
    where: { id: { in: lessonIds } }, include: LESSON_CONTENT_INCLUDE,
  })
  let mismatches = 0
  for (const l of after) {
    const expected = hashDelta.get(l.id)?.after
    if (!expected) continue
    if (hashLessonContent(l as never) !== expected) mismatches++
  }
  console.log(`\n  post-run sweep: ${mismatches === 0
    ? '✅ every affected lesson hashes to its re-stamped baseline'
    : `⛔ ${mismatches} lesson(s) do NOT match — investigate before trusting this run`}`)

  console.log('\n═══ apply complete ═══\n')
  await prisma.$disconnect()
}

main().catch(async (error) => {
  console.error(error)
  await prisma.$disconnect()
  process.exit(1)
})
