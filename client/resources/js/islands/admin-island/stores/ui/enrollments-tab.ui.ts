import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRoute } from 'vue-router'
import { useEnrollmentsDomain, type UnenrollInfo } from '../domain/enrollments.domain'
import { useProgramsDomain } from '../domain/programs.domain'

export const useEnrollmentsTabUI = defineStore('enrollments-tab-ui', () => {
  const domain = useEnrollmentsDomain()
  const programsDomain = useProgramsDomain()
  const route = useRoute()

  // Dialog / panel state
  const isCreateFormOpen = ref(false)
  const expandedEnrollmentId = ref<string | null>(null)
  const confirmDeleteId = ref<string | null>(null)
  const unenrollInfo = ref<UnenrollInfo | null>(null)
  const formError = ref<string | null>(null)
  const isSaving = ref(false)

  // Schedule editing state
  const editingScheduleId = ref<string | null>(null)
  const editingTitle = ref('')
  const confirmDeleteScheduleId = ref<string | null>(null)

  // Form refs — live in the store so the component stays thin
  const selectedDays = ref<string[]>(['MON', 'TUE', 'WED', 'THU', 'FRI'])
  const createForm = ref({
    studyProgramId: '',
    startDate: '',
    smsTime: '',
    timezone: '',
  })

  // Computed state
  const groupId = computed(() => route.params.id as string)

  const enrollments = computed(() => domain.enrollmentsByGroup[groupId.value] ?? [])

  const enrollmentDetail = computed(() =>
    expandedEnrollmentId.value
      ? (domain.enrollmentDetails[expandedEnrollmentId.value] ?? null)
      : null,
  )

  const programOptions = computed(() =>
    programsDomain.programs
      .filter((p) => p.isPublished)
      .map((p) => ({ value: p.id, label: p.name })),
  )

  const isLoading = computed(() => domain.isLoading)

  const createFields = computed(() => [
    {
      key: 'studyProgramId',
      label: 'Program',
      type: 'select' as const,
      required: true,
      options: programOptions.value,
    },
    {
      key: 'startDate',
      label: 'Start Date',
      type: 'text' as const,
      required: true,
      placeholder: 'YYYY-MM-DD',
    },
    {
      key: 'smsTime',
      label: 'SMS Time',
      type: 'text' as const,
      placeholder: 'HH:MM (e.g. 08:00)',
    },
    {
      key: 'timezone',
      label: 'Timezone',
      type: 'select' as const,
      options: [
        { value: 'America/New_York', label: 'Eastern' },
        { value: 'America/Chicago', label: 'Central' },
        { value: 'America/Denver', label: 'Mountain' },
        { value: 'America/Los_Angeles', label: 'Pacific' },
        { value: 'America/Phoenix', label: 'Arizona' },
        { value: 'America/Anchorage', label: 'Alaska' },
        { value: 'Pacific/Honolulu', label: 'Hawaii' },
      ],
    },
  ])

  // Methods
  async function loadData(): Promise<void> {
    const id = groupId.value
    if (!id) return
    await Promise.all([domain.loadEnrollments(id), programsDomain.loadPrograms()])
  }

  function openCreate(): void {
    isCreateFormOpen.value = true
    formError.value = null
    createForm.value = { studyProgramId: '', startDate: '', smsTime: '', timezone: '' }
    selectedDays.value = ['MON', 'TUE', 'WED', 'THU', 'FRI']
  }

  function closeCreate(): void {
    isCreateFormOpen.value = false
  }

  function expandEnrollment(id: string): void {
    expandedEnrollmentId.value = id
    domain.loadEnrollmentDetail(id)
  }

  function collapseEnrollment(): void {
    expandedEnrollmentId.value = null
  }

  async function requestDelete(id: string): Promise<void> {
    try {
      const info = await domain.getUnenrollInfo(id)
      confirmDeleteId.value = id
      unenrollInfo.value = info
    } catch {
      confirmDeleteId.value = id
      unenrollInfo.value = null
    }
  }

  function cancelDelete(): void {
    confirmDeleteId.value = null
    unenrollInfo.value = null
  }

  async function confirmDelete(): Promise<void> {
    if (!confirmDeleteId.value) return
    await domain.deleteEnrollment(confirmDeleteId.value, groupId.value)
    confirmDeleteId.value = null
    unenrollInfo.value = null
  }

  async function handleCancelFuture(id: string): Promise<void> {
    await domain.cancelFuture(id, groupId.value)
  }

  function startEditSchedule(scheduleId: string, currentTitle: string): void {
    editingScheduleId.value = scheduleId
    editingTitle.value = currentTitle
  }

  function cancelEditSchedule(): void {
    editingScheduleId.value = null
    editingTitle.value = ''
  }

  async function saveScheduleTitle(): Promise<void> {
    if (!expandedEnrollmentId.value || !editingScheduleId.value) return
    await domain.updateScheduleTitle(
      expandedEnrollmentId.value,
      editingScheduleId.value,
      editingTitle.value,
    )
    editingScheduleId.value = null
    editingTitle.value = ''
  }

  async function addSchedule(): Promise<void> {
    if (!expandedEnrollmentId.value) return
    await domain.addSchedule(expandedEnrollmentId.value)
  }

  function requestDeleteSchedule(scheduleId: string): void {
    confirmDeleteScheduleId.value = scheduleId
  }

  function cancelDeleteSchedule(): void {
    confirmDeleteScheduleId.value = null
  }

  async function confirmDeleteSchedule(): Promise<void> {
    if (!expandedEnrollmentId.value || !confirmDeleteScheduleId.value) return
    await domain.deleteSchedule(expandedEnrollmentId.value, confirmDeleteScheduleId.value)
    confirmDeleteScheduleId.value = null
  }

  async function submitCreate(): Promise<void> {
    isSaving.value = true
    formError.value = null
    try {
      const payload = {
        groupId: groupId.value,
        studyProgramId: createForm.value.studyProgramId,
        startDate: new Date(createForm.value.startDate + 'T00:00:00.000Z').toISOString(),
        enabledDays: selectedDays.value,
        ...(createForm.value.smsTime ? { smsTime: createForm.value.smsTime } : {}),
        ...(createForm.value.timezone ? { timezone: createForm.value.timezone } : {}),
      }
      await domain.createEnrollment(payload)
      closeCreate()
    } catch (err: any) {
      formError.value = err?.response?.data?.message ?? 'Failed to create enrollment'
    } finally {
      isSaving.value = false
    }
  }

  return {
    isCreateFormOpen,
    expandedEnrollmentId,
    confirmDeleteId,
    unenrollInfo,
    formError,
    isSaving,
    selectedDays,
    createForm,
    groupId,
    enrollments,
    enrollmentDetail,
    programOptions,
    isLoading,
    createFields,
    editingScheduleId,
    editingTitle,
    confirmDeleteScheduleId,
    loadData,
    openCreate,
    closeCreate,
    expandEnrollment,
    collapseEnrollment,
    requestDelete,
    cancelDelete,
    confirmDelete,
    handleCancelFuture,
    submitCreate,
    startEditSchedule,
    cancelEditSchedule,
    saveScheduleTitle,
    addSchedule,
    requestDeleteSchedule,
    cancelDeleteSchedule,
    confirmDeleteSchedule,
  }
})
