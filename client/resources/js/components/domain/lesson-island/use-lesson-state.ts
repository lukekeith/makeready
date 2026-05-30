import { ref, computed, watch, type InjectionKey, type Ref, provide, inject } from 'vue'

// ─── Types ────────────────────────────────────────────────────────────────────

export interface Activity {
  id: string
  type?: string
  activityType?: string
  title?: string
  description?: string
  helpTitle?: string
  helpDescription?: string
  helpAlwaysVisible?: boolean
  helpIcon?: string
  helpText?: string
  isHelpEnabled?: boolean
  noteType?: string
  videoUrl?: string
  video?: { url?: string; playbackUrl?: string }
  note?: { content?: string }
  scripture?: unknown
  scriptures?: unknown[]
  sourceReferences?: Array<{
    id: string
    sourceType: string
    passageReference?: string
    bookNumber?: number
    chapterStart?: number
    verseStart?: number
    verseEnd?: number
  }>
  readBlocks?: Array<{
    id: string
    orderNumber: number
    title?: string
    content?: string
    sourceReferenceId?: string
    selections?: Array<{ start: number; end: number; style: string }> | null
    exegesisHighlights?: Array<{ id: string; orderNumber: number; start: number; end: number; noteMarkdown: string }>
  }>
  readContent?: string
  referenceTitle?: string
  progress?: { completedAt?: string; exegesisVisitedHighlightIds?: string[] | null }
  youtubeUrl?: string
  youtubeVideoId?: string
  youtubeStartSeconds?: number | null
  youtubeEndSeconds?: number | null
  initialHighlightIndex?: number | null
}

export interface Lesson {
  id?: string
  title?: string
  dayNumber?: number
  activities?: Activity[]
  studyEnrollmentId?: string
  studyProgram?: { id?: string; name?: string }
  requireResponse?: boolean
  requireResponses?: boolean
}

export interface LessonData {
  lesson?: Lesson
  [key: string]: unknown
}

export interface Step {
  type: 'video' | 'youtube' | 'read' | 'exegesis' | 'input' | 'complete'
  activity?: Activity
}

// ─── Injection Key ────────────────────────────────────────────────────────────

export interface LessonState {
  // Navigation
  currentStepNumber: Ref<number>
  lesson: Ref<Lesson>
  steps: Ref<Step[]>
  currentStep: Ref<Step | undefined>
  totalSteps: Ref<number>
  activityStepCount: Ref<number>
  isCompleteStep: Ref<boolean>
  isReadStep: Ref<boolean>
  isVideoStep: Ref<boolean>
  isFirstStep: Ref<boolean>
  progressPercent: Ref<number>
  studyEnrollmentId: Ref<string>

  // Progress reporting (set by activities)
  canProceed: Ref<boolean>
  message: Ref<string>
  messageCollapsed: Ref<boolean>
  messageAlert: Ref<boolean>

  // UI persistence
  contextCollapsed: Ref<boolean>

  // Loading state
  isLoading: Ref<boolean>
  isSaving: Ref<boolean>
  hideTitle: Ref<boolean>

  // Before-navigate hook — activities register a callback that fires
  // before any navigation (next, prev, exit). Cleared on step change.
  beforeNavigateHook: Ref<(() => Promise<void>) | null>
  registerBeforeNavigate: (fn: () => Promise<void>) => void

  // Note save callback — set by lesson-island, used by input activities
  saveNote: ((activityId: string, noteType: string, content: string) => Promise<void>) | null

  // Update an activity's local state after a save so navigating back shows current data
  updateActivityState: (activityId: string, updates: Partial<Activity>) => void

  // Methods
  reportProgress: (message: string, canProceed: boolean) => void
  goToStep: (n: number) => Promise<void>
  handleBack: () => Promise<void>
  handleNext: () => Promise<void>
  handleExit: () => Promise<void>
  tryNext: () => Promise<void>
}

export const LESSON_STATE_KEY: InjectionKey<LessonState> = Symbol('lessonState')

export function provideLessonState(state: LessonState) {
  provide(LESSON_STATE_KEY, state)
}

export function useLessonState(): LessonState {
  const state = inject(LESSON_STATE_KEY)
  if (!state) throw new Error('useLessonState() called without provider')
  return state
}

// ─── Factory ──────────────────────────────────────────────────────────────────

export interface CreateLessonStateOptions {
  lessonData: LessonData
  groupId: string
  lessonScheduleId: string
  initialStep: number
  isPreview: boolean
  previewToken: string
  singleActivity: boolean
  onSaveNote?: (activityId: string, noteType: string, content: string) => Promise<void>
}

export function createLessonState(opts: CreateLessonStateOptions): LessonState {
  // ─── Core state ─────────────────────────────────────────────────────────────

  const currentStepNumber = ref(opts.initialStep)
  const lesson = ref<Lesson>(opts.lessonData?.lesson ?? (opts.lessonData as unknown as Lesson))
  const isLoading = ref(false)
  const isSaving = ref(false)
  const hideTitle = ref(false)
  const contextCollapsed = ref(false)

  // ─── Progress reporting ─────────────────────────────────────────────────────

  const canProceed = ref(false)
  const message = ref('')
  const messageCollapsed = ref(false)
  const messageAlert = ref(false)

  let alertTimer: ReturnType<typeof setTimeout> | null = null

  function reportProgress(msg: string, proceed: boolean) {
    message.value = msg
    canProceed.value = proceed
  }

  // ─── Before-navigate hook ───────────────────────────────────────────────────

  const beforeNavigateHook = ref<(() => Promise<void>) | null>(null)

  function registerBeforeNavigate(fn: () => Promise<void>) {
    beforeNavigateHook.value = fn
  }

  async function runBeforeNavigate() {
    if (beforeNavigateHook.value) {
      await beforeNavigateHook.value()
    }
  }

  // Reset activity-level state when navigating between steps.
  // messageCollapsed persists across steps intentionally.
  watch(currentStepNumber, () => {
    canProceed.value = false
    message.value = ''
    hideTitle.value = false
    messageAlert.value = false
    beforeNavigateHook.value = null
    if (alertTimer) {
      clearTimeout(alertTimer)
      alertTimer = null
    }
  })

  // ─── Computed ───────────────────────────────────────────────────────────────

  const steps = computed<Step[]>(() => {
    const activities = lesson.value?.activities ?? []
    const result: Step[] = []

    for (const activity of activities) {
      const type = (activity.type || activity.activityType)?.toUpperCase()
      if (type === 'VIDEO') {
        result.push({ type: 'video', activity })
      } else if (type === 'YOUTUBE') {
        result.push({ type: 'youtube', activity })
      } else if (type === 'READ' || type === 'SCRIPTURE') {
        result.push({ type: 'read', activity })
      } else if (type === 'EXEGESIS') {
        result.push({ type: 'exegesis', activity })
      } else if (type === 'USER_INPUT' || type === 'INPUT' || type === 'SOAP') {
        result.push({ type: 'input', activity })
      }
    }

    if (!opts.singleActivity) {
      result.push({ type: 'complete' })
    }
    return result
  })

  const currentStep = computed<Step | undefined>(() => steps.value[currentStepNumber.value - 1])
  const totalSteps = computed(() => steps.value.length)
  const activityStepCount = computed(() => totalSteps.value - 1)
  const isCompleteStep = computed(() => currentStep.value?.type === 'complete')
  const isReadStep = computed(() => currentStep.value?.type === 'read' || currentStep.value?.type === 'exegesis')
  const isVideoStep = computed(() => currentStep.value?.type === 'video' || currentStep.value?.type === 'youtube')
  const isFirstStep = computed(() => currentStepNumber.value === 1)
  const studyEnrollmentId = computed(() => lesson.value?.studyEnrollmentId ?? '')

  const progressPercent = computed(() => {
    const total = activityStepCount.value
    if (total <= 0) return 100
    const current = isCompleteStep.value ? total : currentStepNumber.value
    return Math.round((current / total) * 100)
  })

  // ─── Activity state updates ─────────────────────────────────────────────────

  function updateActivityState(activityId: string, updates: Partial<Activity>) {
    const activities = lesson.value?.activities
    if (!activities) return
    const activity = activities.find(a => a.id === activityId)
    if (activity) Object.assign(activity, updates)
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  function buildLessonUrl(stepNum: number): string {
    if (opts.isPreview) {
      const lessonId = lesson.value?.id ?? ''
      if (opts.previewToken) {
        return `/preview/lesson/${lessonId}/${stepNum}?preview_token=${opts.previewToken}`
      }
      return `/preview/lesson/${lessonId}/${stepNum}`
    }
    return `/member/groups/${opts.groupId}/lessons/${opts.lessonScheduleId}/${stepNum}`
  }

  function getExitUrl(): string {
    if (opts.isPreview && opts.previewToken) {
      return `/preview/study/${lesson.value?.studyProgram?.id ?? ''}?preview_token=${opts.previewToken}`
    }
    // Synthetic preview (pvw- prefix) — exit to study overview
    if (opts.groupId.startsWith('pvw-') && opts.previewToken) {
      return `/preview/study/${lesson.value?.studyProgram?.id ?? ''}?preview_token=${opts.previewToken}`
    }
    const enrollmentId = studyEnrollmentId.value
    if (enrollmentId) {
      return `/member/groups/${opts.groupId}/study/${enrollmentId}`
    }
    return `/member/groups/${opts.groupId}`
  }

  async function goToStep(n: number) {
    if (n < 1 || n > totalSteps.value) return
    await runBeforeNavigate()
    currentStepNumber.value = n
    window.history.pushState({ step: n }, '', buildLessonUrl(n))
  }

  async function handleBack() {
    if (isFirstStep.value) return
    await goToStep(currentStepNumber.value - 1)
  }

  async function handleNext() {
    await goToStep(currentStepNumber.value + 1)
  }

  async function handleExit() {
    await runBeforeNavigate()
    window.location.href = getExitUrl()
  }

  async function tryNext() {
    if (isCompleteStep.value) {
      await handleExit()
      return
    }
    if (!canProceed.value) {
      messageAlert.value = true
      if (alertTimer) clearTimeout(alertTimer)
      alertTimer = setTimeout(() => {
        messageAlert.value = false
        alertTimer = null
      }, 3000)
      return
    }
    await handleNext()
  }

  return {
    currentStepNumber,
    lesson,
    steps: computed(() => steps.value),
    currentStep: computed(() => currentStep.value),
    totalSteps: computed(() => totalSteps.value),
    activityStepCount: computed(() => activityStepCount.value),
    isCompleteStep: computed(() => isCompleteStep.value),
    isReadStep: computed(() => isReadStep.value),
    isVideoStep: computed(() => isVideoStep.value),
    isFirstStep: computed(() => isFirstStep.value),
    progressPercent: computed(() => progressPercent.value),
    studyEnrollmentId: computed(() => studyEnrollmentId.value),
    canProceed,
    message,
    messageCollapsed,
    messageAlert,
    contextCollapsed,
    isLoading,
    isSaving,
    hideTitle,
    beforeNavigateHook,
    registerBeforeNavigate,
    saveNote: opts.onSaveNote ?? null,
    updateActivityState,
    reportProgress,
    goToStep,
    handleBack,
    handleNext,
    handleExit,
    tryNext,
  }
}
