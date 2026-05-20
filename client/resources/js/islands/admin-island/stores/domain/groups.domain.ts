import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

export interface Group {
  id: string
  name: string
  description?: string
  coverImageUrl?: string
  isPrivate: boolean
  allowInvites: boolean
  memberDirectory: boolean
  welcomeMessage?: string
  ageRange?: { min?: number; max?: number }
  maxMembers?: number
  memberCount?: number
}

export interface CreateGroupPayload {
  name: string
  description?: string
  isPrivate?: boolean
  allowInvites?: boolean
  memberDirectory?: boolean
}

export interface UpdateGroupPayload {
  name?: string
  description?: string
  coverImageUrl?: string
  isPrivate?: boolean
  allowInvites?: boolean
  memberDirectory?: boolean
  welcomeMessage?: string
  ageRange?: { min?: number; max?: number }
  maxMembers?: number
}

export const useGroupsDomain = defineStore('groups-domain', () => {
  const groups = ref<Group[]>([])
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadGroups(): Promise<void> {
    isLoading.value = true
    error.value = null
    try {
      const res = await axios.get('/admin/api/groups')
      groups.value = res.data.groups ?? []
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load groups'
    } finally {
      isLoading.value = false
    }
  }

  async function getGroup(id: string): Promise<void> {
    error.value = null
    try {
      const res = await axios.get(`/admin/api/groups/${id}`)
      const fetched: Group = res.data.group
      const idx = groups.value.findIndex((g) => g.id === id)
      if (idx !== -1) {
        groups.value.splice(idx, 1, fetched)
      } else {
        groups.value.push(fetched)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load group'
    }
  }

  async function createGroup(payload: CreateGroupPayload): Promise<void> {
    error.value = null
    try {
      const res = await axios.post('/admin/api/groups', payload)
      groups.value.push(res.data.group)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to create group'
      throw err
    }
  }

  async function updateGroup(id: string, payload: UpdateGroupPayload): Promise<void> {
    error.value = null
    try {
      const res = await axios.patch(`/admin/api/groups/${id}`, payload)
      const updated: Group = res.data.group
      const idx = groups.value.findIndex((g) => g.id === id)
      if (idx !== -1) {
        groups.value.splice(idx, 1, updated)
      } else {
        groups.value.push(updated)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to update group'
      throw err
    }
  }

  async function deleteGroup(id: string): Promise<void> {
    error.value = null
    try {
      await axios.delete(`/admin/api/groups/${id}`)
      groups.value = groups.value.filter((g) => g.id !== id)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to delete group'
      throw err
    }
  }

  async function uploadCoverImage(id: string, file: File): Promise<void> {
    error.value = null
    try {
      const formData = new FormData()
      formData.append('image', file)
      const res = await axios.post(`/admin/api/groups/${id}/cover-image`, formData)
      const updated: Group = res.data.group
      const idx = groups.value.findIndex((g) => g.id === id)
      if (idx !== -1) {
        groups.value.splice(idx, 1, { ...groups.value[idx], coverImageUrl: updated.coverImageUrl })
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to upload cover image'
      throw err
    }
  }

  return {
    groups,
    isLoading,
    error,
    loadGroups,
    getGroup,
    createGroup,
    updateGroup,
    deleteGroup,
    uploadCoverImage,
  }
})
