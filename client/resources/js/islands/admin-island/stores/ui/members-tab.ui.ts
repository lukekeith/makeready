import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRoute } from 'vue-router'
import { useMembersDomain, type MemberProfile } from '../domain/members.domain'

export const useMembersTabUI = defineStore('members-tab-ui', () => {
  const domain = useMembersDomain()
  const route = useRoute()

  const selectedMemberId = ref<string | null>(null)
  const profileData = ref<MemberProfile | null>(null)
  const isProfileOpen = ref(false)
  const confirmRemoveId = ref<string | null>(null)
  const roleChangeTarget = ref<{ memberId: string; currentRole: string } | null>(null)

  const groupId = computed(() => route.params.id as string)

  const members = computed(() => domain.membersByGroup[groupId.value] ?? [])

  const pendingRequests = computed(() => domain.requestsByGroup[groupId.value] ?? [])

  const hasPending = computed(() => pendingRequests.value.length > 0)

  const isLoading = computed(() => domain.isLoading)

  async function loadData(): Promise<void> {
    const id = groupId.value
    if (!id) return
    await Promise.all([domain.loadMembers(id), domain.loadJoinRequests(id)])
  }

  async function openProfile(memberId: string): Promise<void> {
    selectedMemberId.value = memberId
    try {
      const profile = await domain.loadMemberProfile(memberId)
      profileData.value = profile
      isProfileOpen.value = true
    } catch {
      selectedMemberId.value = null
    }
  }

  function closeProfile(): void {
    profileData.value = null
    isProfileOpen.value = false
    selectedMemberId.value = null
  }

  function requestRemove(memberId: string): void {
    confirmRemoveId.value = memberId
  }

  function cancelRemove(): void {
    confirmRemoveId.value = null
  }

  async function confirmRemove(): Promise<void> {
    if (!confirmRemoveId.value) return
    await domain.removeMember(groupId.value, confirmRemoveId.value)
    confirmRemoveId.value = null
  }

  function openRoleChange(memberId: string, currentRole: string): void {
    roleChangeTarget.value = { memberId, currentRole }
  }

  async function confirmRoleChange(newRole: string): Promise<void> {
    if (!roleChangeTarget.value) return
    await domain.changeRole(
      groupId.value,
      roleChangeTarget.value.memberId,
      newRole as 'ADMIN' | 'MEMBER',
    )
    roleChangeTarget.value = null
  }

  return {
    selectedMemberId,
    profileData,
    isProfileOpen,
    confirmRemoveId,
    roleChangeTarget,
    groupId,
    members,
    pendingRequests,
    hasPending,
    isLoading,
    loadData,
    openProfile,
    closeProfile,
    requestRemove,
    cancelRemove,
    confirmRemove,
    openRoleChange,
    confirmRoleChange,
  }
})
