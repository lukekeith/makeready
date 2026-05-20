import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import { useMembersDomain, type MemberProfile } from '../domain/members.domain'
import { useGroupsDomain } from '../domain/groups.domain'
import { useAllMembersDomain } from '../domain/all-members.domain'

export interface EnrollmentProgress {
  programName: string
  progressPercentage: number
  completedLessons: number
  totalLessons: number
}

export const useMemberDetailUI = defineStore('member-detail-ui', () => {
  const membersDomain = useMembersDomain()
  const groupsDomain = useGroupsDomain()
  const allMembersDomain = useAllMembersDomain()

  const isOpen = ref(false)
  const selectedMemberId = ref<string | null>(null)
  const profile = ref<MemberProfile | null>(null)
  const enrollmentProgress = ref<EnrollmentProgress[]>([])
  const isLoadingProfile = ref(false)
  const isLoadingEnrollments = ref(false)
  const isAddingToGroup = ref(false)
  const isRemovingFromGroup = ref(false)
  const error = ref<string | null>(null)

  // Computed display props
  const displayName = computed(() => {
    if (!profile.value) return ''
    const parts = [profile.value.firstName, profile.value.lastName].filter(Boolean)
    return parts.length > 0 ? parts.join(' ') : 'Unknown'
  })

  const avatarUrl = computed<string | null>(() => {
    return profile.value?.profilePicture ?? profile.value?.googlePicture ?? null
  })

  const initials = computed(() => {
    if (!profile.value) return '?'
    const first = profile.value.firstName?.charAt(0)?.toUpperCase() ?? ''
    const last = profile.value.lastName?.charAt(0)?.toUpperCase() ?? ''
    const result = first + last
    return result || '?'
  })

  const joinedDate = computed(() => {
    if (!profile.value || profile.value.groups.length === 0) return ''
    const dates = profile.value.groups
      .map((g) => new Date(g.joinedAt))
      .filter((d) => !isNaN(d.getTime()))
    if (dates.length === 0) return ''
    const earliest = new Date(Math.min(...dates.map((d) => d.getTime())))
    return `Joined ${earliest.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`
  })

  const groupsWithMeta = computed(() => {
    return profile.value?.groups ?? []
  })

  const availableGroups = computed<Array<{ id: string; name: string }>>(() => {
    const memberGroupIds = new Set((profile.value?.groups ?? []).map((g) => g.id))
    return groupsDomain.groups
      .filter((g) => !memberGroupIds.has(g.id))
      .map((g) => ({ id: g.id, name: g.name }))
  })

  // Actions
  async function loadProfile(): Promise<void> {
    if (!selectedMemberId.value) return
    isLoadingProfile.value = true
    error.value = null
    try {
      profile.value = await membersDomain.loadMemberProfile(selectedMemberId.value)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load member profile'
    } finally {
      isLoadingProfile.value = false
    }
  }

  async function loadEnrollmentProgress(): Promise<void> {
    if (!selectedMemberId.value) return
    isLoadingEnrollments.value = true
    try {
      const res = await axios.get(`/admin/api/members/${selectedMemberId.value}/enrollments`)
      const enrollments = res.data?.enrollments ?? []
      enrollmentProgress.value = enrollments.map((e: any) => ({
        programName: e.studyProgram?.name ?? 'Unknown Program',
        progressPercentage: e.progressPercentage ?? 0,
        completedLessons: e.completedLessons ?? 0,
        totalLessons: e.totalLessons ?? 0,
      }))
    } catch {
      // Gracefully handle missing enrollments — not all members are enrolled
      enrollmentProgress.value = []
    } finally {
      isLoadingEnrollments.value = false
    }
  }

  async function addToGroup(groupId: string): Promise<void> {
    if (!selectedMemberId.value) return
    isAddingToGroup.value = true
    error.value = null
    try {
      await axios.post(`/admin/api/groups/${groupId}/members`, { userId: selectedMemberId.value })
      await membersDomain.loadMembers(groupId, true)
      await loadProfile()
      await allMembersDomain.loadAll()
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to add to group'
    } finally {
      isAddingToGroup.value = false
    }
  }

  async function removeFromGroup(groupId: string): Promise<void> {
    if (!selectedMemberId.value) return
    isRemovingFromGroup.value = true
    error.value = null
    try {
      // Find the membership ID for this member in the group
      const groupMembers = membersDomain.membersByGroup[groupId] ?? []
      const membership = groupMembers.find((m) => m.userId === selectedMemberId.value)
      if (!membership) {
        // If not cached, still attempt the operation using the userId directly
        // after loading the group members first
        await membersDomain.loadMembers(groupId, true)
        const refreshed = membersDomain.membersByGroup[groupId] ?? []
        const found = refreshed.find((m) => m.userId === selectedMemberId.value)
        if (!found) throw new Error('Membership not found')
        await membersDomain.removeMember(groupId, found.id)
      } else {
        await membersDomain.removeMember(groupId, membership.id)
      }
      await membersDomain.loadMembers(groupId, true)
      await loadProfile()
      await allMembersDomain.loadAll()
    } catch (err: any) {
      error.value = err?.message ?? err?.response?.data?.message ?? 'Failed to remove from group'
    } finally {
      isRemovingFromGroup.value = false
    }
  }

  function openDrawer(userId: string): void {
    selectedMemberId.value = userId
    isOpen.value = true
    Promise.all([loadProfile(), loadEnrollmentProgress()])
  }

  function closeDrawer(): void {
    isOpen.value = false
    // Delay reset to allow the slide-out transition to complete
    setTimeout(() => {
      selectedMemberId.value = null
      profile.value = null
      enrollmentProgress.value = []
      error.value = null
    }, 200)
  }

  return {
    isOpen,
    selectedMemberId,
    profile,
    enrollmentProgress,
    isLoadingProfile,
    isLoadingEnrollments,
    isAddingToGroup,
    isRemovingFromGroup,
    error,
    displayName,
    avatarUrl,
    initials,
    joinedDate,
    groupsWithMeta,
    availableGroups,
    openDrawer,
    closeDrawer,
    loadProfile,
    loadEnrollmentProgress,
    addToGroup,
    removeFromGroup,
  }
})
