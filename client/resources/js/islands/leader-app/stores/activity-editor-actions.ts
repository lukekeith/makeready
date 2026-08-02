import type { LeaderPassage } from './leader-program.store'
import { useLeaderProgram } from './leader-program.store'

// ActivityEditorActions — web port of the iPhone per-editor action providers
// (ReadActivityActionProvider / ExegesisActivityActionProvider /
// YouTubeActivityActionProvider in Pages/Manage/Program/Edit*ActivityPage.swift).
// The shared READ / EXEGESIS editor panes call these closures instead of a
// store directly, so the SAME pane serves program activities
// (/api/activities/…) and scheduled activities (/api/scheduled-activities/…).
// `programActivityActions` is the `.program` default; the enrollment-schedule
// store provides the `.enrollment` variant.

export interface ExegesisHighlightData {
  id: string
  start: number
  end: number
  noteMarkdown: string
}

export interface ActivityEditorActions {
  /** iOS LessonContext — which store owns the live data. */
  context: 'program' | 'enrollment'
  /** iOS supportsBlockStyling — false in the SCHEDULED context: the exegesis
   *  image/color/font row is hidden and style re-apply/revert is skipped. */
  supportsBlockStyling: boolean
  /** PATCH the activity itself (title etc.). */
  updateActivity(fields: Record<string, unknown>): Promise<void>
  createReadBlock(fields: {
    title?: string
    content?: string
    isLocked: boolean
    orderNumber?: number
  }): Promise<void>
  updateReadBlock(blockId: string, fields: Record<string, unknown>): Promise<void>
  deleteReadBlock(blockId: string): Promise<void>
  reorderReadBlocks(blockIds: string[]): Promise<void>
  addSourceReference(
    passage: LeaderPassage & { reference: string },
    content?: string | null,
  ): Promise<void>
  fetchExegesisHighlights(): Promise<ExegesisHighlightData[]>
  createExegesisHighlight(
    blockId: string,
    range: { start: number; end: number },
    noteMarkdown?: string,
  ): Promise<ExegesisHighlightData | null>
  updateExegesisHighlightNote(highlightId: string, noteMarkdown: string): Promise<void>
  deleteExegesisHighlight(
    blockId: string,
    highlight: { id: string; start: number; end: number },
  ): Promise<void>
  /** iOS AppState.passagesUsedIn(lessonId:context:) — the "already used"
   *  tinting in the Bible passage picker. */
  usedPassages(): LeaderPassage[]
  /** Set-titles modal context (iOS currentLessonTitle / lessonActivityCount). */
  lessonTitle(): string
  lessonActivityCount(): number
  /** iOS onLessonTitleUpdate — ABSENT in the enrollment context, where the
   *  set-titles modal's Lesson toggle silently no-ops (faithful port). */
  updateLessonTitle?: (title: string) => Promise<void>
}

/** The `.program` default provider, backed by useLeaderProgram(). */
export function programActivityActions(
  programId: string,
  lessonId: string,
  activityId: string,
): ActivityEditorActions {
  const store = useLeaderProgram()
  const lesson = () => store.program?.lessons.find((l) => l.id === lessonId)
  return {
    context: 'program',
    supportsBlockStyling: true,
    updateActivity: (fields) => store.updateActivity(lessonId, activityId, fields),
    createReadBlock: (fields) => store.createReadBlock(lessonId, activityId, fields),
    updateReadBlock: (blockId, fields) =>
      store.updateReadBlock(lessonId, activityId, blockId, fields),
    deleteReadBlock: (blockId) => store.deleteReadBlock(lessonId, activityId, blockId),
    reorderReadBlocks: (blockIds) => store.reorderReadBlocks(lessonId, activityId, blockIds),
    addSourceReference: (passage, content) =>
      store.addSourceReference(lessonId, activityId, passage, content),
    fetchExegesisHighlights: () => store.fetchExegesisHighlights(activityId),
    createExegesisHighlight: (blockId, range, noteMarkdown) =>
      store.createExegesisHighlight(lessonId, activityId, blockId, range, noteMarkdown),
    updateExegesisHighlightNote: (highlightId, noteMarkdown) =>
      store.updateExegesisHighlightNote(activityId, highlightId, noteMarkdown),
    deleteExegesisHighlight: (blockId, highlight) =>
      store.deleteExegesisHighlight(lessonId, activityId, blockId, highlight),
    usedPassages: () => (lesson()?.activities ?? []).flatMap((a) => a.passages),
    lessonTitle: () => lesson()?.title || 'Untitled lesson',
    lessonActivityCount: () => lesson()?.activities.length ?? 0,
    updateLessonTitle: (title) => store.updateLessonTitle(programId, lessonId, title),
  }
}
