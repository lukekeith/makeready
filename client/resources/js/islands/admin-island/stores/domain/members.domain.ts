import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

export interface GroupMember {
  id: string
  userId: string
  groupId: string
  role: 'OWNER' | 'ADMIN' | 'MEMBER'
  name: string
  avatarUrl?: string
  joinedAt: string
}

export interface JoinRequest {
  id: string
  status: string
  message?: string
  createdAt: string
  member: {
    id: string
    firstName?: string
    lastName?: string
    avatarUrl?: string
  }
}

export interface MemberProfile {
  id: string
  firstName?: string
  lastName?: string
  phoneNumber: string
  email?: string
  profilePicture?: string
  googlePicture?: string
  groups: Array<{
    id: string
    name: string
    coverImageUrl?: string
    role: string
    joinedAt: string
  }>
}

export const useMembersDomain = defineStore('members-domain', () => {
  const membersByGroup = ref<Record<string, GroupMember[]>>({})
  const requestsByGroup = ref<Record<string, JoinRequest[]>>({})
  const loadedGroupIds = ref(new Set<string>())
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadMembers(groupId: string, force = false): Promise<void> {
    if (loadedGroupIds.value.has(groupId) && !force) return
    isLoading.value = true
    error.value = null
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/members`)
      membersByGroup.value[groupId] = res.data.members ?? []
      loadedGroupIds.value.add(groupId)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load members'
    } finally {
      isLoading.value = false
    }
  }

  async function loadJoinRequests(groupId: string): Promise<void> {
    error.value = null
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/join-requests`)
      requestsByGroup.value[groupId] = res.data.joinRequests ?? []
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load join requests'
    }
  }

  async function loadMemberProfile(memberId: string): Promise<MemberProfile> {
    const res = await axios.get(`/admin/api/members/${memberId}/profile`)
    return res.data.data
  }

  async function approveRequest(groupId: string, requestId: string): Promise<void> {
    await axios.post(`/admin/api/groups/${groupId}/join-requests/${requestId}/approve`, {})
    // Filter request from local list
    if (requestsByGroup.value[groupId]) {
      requestsByGroup.value[groupId] = requestsByGroup.value[groupId].filter(
        (r) => r.id !== requestId,
      )
    }
    // Refresh members list to include newly approved member
    await loadMembers(groupId, true)
  }

  async function rejectRequest(groupId: string, requestId: string): Promise<void> {
    try {
      await axios.delete(`/admin/api/groups/${groupId}/join-requests/${requestId}`)
      if (requestsByGroup.value[groupId]) {
        requestsByGroup.value[groupId] = requestsByGroup.value[groupId].filter(
          (r) => r.id !== requestId,
        )
      }
    } catch (err: any) {
      throw new Error(
        err?.response?.data?.message ?? 'Reject is not available',
      )
    }
  }

  async function changeRole(
    groupId: string,
    memberId: string,
    role: 'ADMIN' | 'MEMBER',
  ): Promise<void> {
    try {
      await axios.patch(`/admin/api/groups/${groupId}/members/${memberId}`, { role })
      // Update local state
      if (membersByGroup.value[groupId]) {
        const idx = membersByGroup.value[groupId].findIndex((m) => m.id === memberId)
        if (idx !== -1) {
          membersByGroup.value[groupId][idx] = {
            ...membersByGroup.value[groupId][idx],
            role,
          }
        }
      }
    } catch (err: any) {
      throw new Error(
        err?.response?.data?.message ?? 'Role change is not available',
      )
    }
  }

  async function removeMember(groupId: string, memberId: string): Promise<void> {
    try {
      await axios.delete(`/admin/api/groups/${groupId}/members/${memberId}`)
      if (membersByGroup.value[groupId]) {
        membersByGroup.value[groupId] = membersByGroup.value[groupId].filter(
          (m) => m.id !== memberId,
        )
      }
    } catch (err: any) {
      throw new Error(
        err?.response?.data?.message ?? 'Remove member is not available',
      )
    }
  }

  return {
    membersByGroup,
    requestsByGroup,
    loadedGroupIds,
    isLoading,
    error,
    loadMembers,
    loadJoinRequests,
    loadMemberProfile,
    approveRequest,
    rejectRequest,
    changeRole,
    removeMember,
  }
})
