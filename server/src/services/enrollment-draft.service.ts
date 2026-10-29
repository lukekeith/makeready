/**
 * Enrollment drafts (ui2-enrollments-browse SC2 — D2–D6, D10, D19, D24): a 2.0 enroll checklist saved
 * once it holds a group and a program. Scope is always the draft's GROUP (groupManageFilter, active);
 * the program must be active, and readable (programReadFilter) when a draft is created on it or moved
 * to it. One draft per (group, program): a unique violation is a 409 carrying the holder's id.
 */
import { z } from 'zod'
import type { EnrollmentSyncMode, LessonAccess } from '../generated/prisma/index.js'
import { Prisma, prisma } from '../lib/prisma.js'
import { isValidTimezone } from '../utils/timezone.js'
import { findManageableGroup, groupManageFilter } from './permission.js'
import { programReadFilter } from './study-program.service.js'

const ymd = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'expected yyyy-MM-dd')
const weekday = z.enum(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])

// Every checklist field: absent = leave as is, null = clear (written only when the key is present).
const draftFields = {
  startDate: ymd.nullable().optional(),
  enabledDays: z.array(weekday).nullable().optional(),
  overriddenDates: z.array(ymd).nullable().optional(),
  // Strictly ascending; the count and not-before-today are Enroll's checks, never the draft's.
  scheduleDates: z
    .array(ymd)
    .refine((d) => d.every((v, i) => i === 0 || d[i - 1] < v), 'scheduleDates must be strictly ascending')
    .nullable()
    .optional(),
  smsTime: z.string().regex(/^\d{2}:\d{2}$/, 'expected HH:mm').nullable().optional(),
  timezone: z.string().refine(isValidTimezone, { message: 'Invalid timezone' }).nullable().optional(),
  syncMode: z.enum(['AUTO', 'OFF']).nullable().optional(),
  lessonAccess: z.enum(['ONE_AT_A_TIME', 'ALL_AT_ONCE']).nullable().optional(),
}

export const draftCreateSchema = z
  .object({ groupId: z.string().uuid(), studyProgramId: z.string().uuid(), ...draftFields })
  .strict()
export const draftPatchSchema = z
  .object({ groupId: z.string().uuid().optional(), studyProgramId: z.string().uuid().optional(), ...draftFields })
  .strict()
export type DraftCreateInput = z.infer<typeof draftCreateSchema>
export type DraftPatchInput = z.infer<typeof draftPatchSchema>

const DRAFT_FIELD_KEYS = [
  'startDate', 'enabledDays', 'overriddenDates', 'scheduleDates', 'smsTime', 'timezone', 'syncMode', 'lessonAccess',
] as const
type DraftFieldKey = (typeof DRAFT_FIELD_KEYS)[number]
const JSON_FIELD_KEYS: ReadonlySet<DraftFieldKey> = new Set(['enabledDays', 'overriddenDates', 'scheduleDates'])

/** Only the keys the body carried; a JSON column's null is Prisma.DbNull (SQL NULL). */
function presentFields(input: Partial<Record<DraftFieldKey, unknown>>): Record<string, unknown> {
  const data: Record<string, unknown> = {}
  for (const key of DRAFT_FIELD_KEYS) {
    const value = input[key]
    if (value === undefined) continue
    data[key] = value === null && JSON_FIELD_KEYS.has(key) ? Prisma.DbNull : value
  }
  return data
}

export const DRAFT_SELECT = {
  id: true,
  groupId: true,
  studyProgramId: true,
  startDate: true,
  enabledDays: true,
  overriddenDates: true,
  scheduleDates: true,
  smsTime: true,
  timezone: true,
  syncMode: true,
  lessonAccess: true,
  createdAt: true,
  updatedAt: true,
  createdBy: { select: { id: true, name: true } },
} satisfies Prisma.EnrollmentDraftSelect
export type DraftRow = Prisma.EnrollmentDraftGetPayload<{ select: typeof DRAFT_SELECT }>

/** §Contract Draft. */
export interface DraftWire {
  id: string
  groupId: string
  studyProgramId: string
  startDate: string | null
  enabledDays: string[] | null
  overriddenDates: string[] | null
  scheduleDates: string[] | null
  smsTime: string | null
  timezone: string | null
  syncMode: EnrollmentSyncMode | null
  lessonAccess: LessonAccess | null
  createdBy: { id: string; name: string } | null
  createdAt: string
  updatedAt: string
}

const asStrings = (v: Prisma.JsonValue | null): string[] | null => (Array.isArray(v) ? (v as string[]) : null)

export function toDraftWire(row: DraftRow): DraftWire {
  return {
    id: row.id,
    groupId: row.groupId,
    studyProgramId: row.studyProgramId,
    startDate: row.startDate,
    enabledDays: asStrings(row.enabledDays),
    overriddenDates: asStrings(row.overriddenDates),
    scheduleDates: asStrings(row.scheduleDates),
    smsTime: row.smsTime,
    timezone: row.timezone,
    syncMode: row.syncMode,
    lessonAccess: row.lessonAccess,
    createdBy: row.createdBy ? { id: row.createdBy.id, name: row.createdBy.name } : null,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  }
}

export class DraftError extends Error {
  constructor(
    readonly status: 404 | 409,
    message: string,
    readonly draftId?: string,
  ) {
    super(message)
    this.name = 'DraftError'
  }
}

const isUniqueViolation = (error: unknown): boolean =>
  typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 'P2002'

/** D5 + D19: the draft's group is manageable and active, its program active. */
async function draftScope(userId: string): Promise<Prisma.EnrollmentDraftWhereInput> {
  return { group: { isActive: true, ...(await groupManageFilter(userId)) }, studyProgram: { isActive: true } }
}

async function findReadableProgram(userId: string, id: string): Promise<{ id: string } | null> {
  return prisma.studyProgram.findFirst({ where: { id, isActive: true, ...(await programReadFilter(userId)) }, select: { id: true } })
}

/** D6: the pair is held — 409 with the holder's id (the caller already proved the pair's group in scope). */
async function conflictFor(groupId: string, studyProgramId: string, original: unknown): Promise<never> {
  const holder = await prisma.enrollmentDraft.findUnique({
    where: { groupId_studyProgramId: { groupId, studyProgramId } },
    select: { id: true },
  })
  if (holder) throw new DraftError(409, 'draft_exists', holder.id)
  throw original
}

export async function createDraft(userId: string, input: DraftCreateInput): Promise<DraftWire> {
  if (!(await findManageableGroup(userId, input.groupId))) throw new DraftError(404, 'Group not found')
  if (!(await findReadableProgram(userId, input.studyProgramId))) throw new DraftError(404, 'Study program not found')
  try {
    const row = await prisma.enrollmentDraft.create({
      data: {
        ...presentFields(input),
        groupId: input.groupId,
        studyProgramId: input.studyProgramId,
        createdById: userId,
        updatedById: userId,
      } as Prisma.EnrollmentDraftUncheckedCreateInput,
      select: DRAFT_SELECT,
    })
    return toDraftWire(row)
  } catch (error) {
    if (isUniqueViolation(error)) return conflictFor(input.groupId, input.studyProgramId, error)
    throw error
  }
}

export async function listGroupDrafts(userId: string, groupId: string): Promise<DraftWire[]> {
  if (!(await findManageableGroup(userId, groupId))) throw new DraftError(404, 'Group not found')
  const rows = await prisma.enrollmentDraft.findMany({
    where: { groupId, studyProgram: { isActive: true } },
    orderBy: [{ updatedAt: 'desc' }, { id: 'asc' }],
    select: DRAFT_SELECT,
  })
  return rows.map(toDraftWire)
}

async function findDraftInScope(userId: string, id: string) {
  return prisma.enrollmentDraft.findFirst({ where: { id, ...(await draftScope(userId)) }, select: DRAFT_SELECT })
}

export async function getDraft(userId: string, id: string): Promise<DraftWire> {
  const row = await findDraftInScope(userId, id)
  if (!row) throw new DraftError(404, 'Draft not found')
  return toDraftWire(row)
}

export async function updateDraft(userId: string, id: string, patch: DraftPatchInput): Promise<DraftWire> {
  const current = await findDraftInScope(userId, id)
  if (!current) throw new DraftError(404, 'Draft not found')
  const groupId = patch.groupId ?? current.groupId
  const studyProgramId = patch.studyProgramId ?? current.studyProgramId
  if (groupId !== current.groupId && !(await findManageableGroup(userId, groupId))) {
    throw new DraftError(404, 'Group not found')
  }
  if (studyProgramId !== current.studyProgramId && !(await findReadableProgram(userId, studyProgramId))) {
    throw new DraftError(404, 'Study program not found')
  }
  try {
    const row = await prisma.enrollmentDraft.update({
      where: { id },
      data: { ...presentFields(patch), groupId, studyProgramId, updatedById: userId } as Prisma.EnrollmentDraftUncheckedUpdateInput,
      select: DRAFT_SELECT,
    })
    return toDraftWire(row)
  } catch (error) {
    if (isUniqueViolation(error)) return conflictFor(groupId, studyProgramId, error)
    throw error
  }
}

export async function deleteDraft(userId: string, id: string): Promise<void> {
  const row = await findDraftInScope(userId, id)
  if (!row) throw new DraftError(404, 'Draft not found')
  await prisma.enrollmentDraft.delete({ where: { id } })
}

/** D11 + D24: enrolling a (group, program) promotes its draft — every draft of the pair goes. */
export async function deleteDraftsForPair(groupId: string, studyProgramId: string): Promise<number> {
  const { count } = await prisma.enrollmentDraft.deleteMany({ where: { groupId, studyProgramId } })
  return count
}
