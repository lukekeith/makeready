import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

export type PostType = 'ANNOUNCEMENT' | 'POLL' | 'EVENT' | 'VIDEO' | 'WELCOME'

export interface PollOption {
  id: string
  text: string
  voteCount: number
  hasVoted: boolean
}

export interface GroupPost {
  id: string
  groupId: string
  authorId?: string
  authorName: string
  authorAvatarUrl?: string
  type: PostType
  content: string
  title?: string
  pollOptions?: PollOption[]
  videoUrl?: string
  eventDate?: string
  eventLocation?: string
  eventTitle?: string
  viewCount?: number
  shareCount?: number
  createdAt: string
  updatedAt: string
}

export interface CreatePostPayload {
  type: PostType
  content: string
  title?: string
  pollOptions?: string[]
  videoUrl?: string
  eventDate?: string
  eventLocation?: string
}

export const usePostsDomain = defineStore('posts-domain', () => {
  const postsByGroup = ref<Record<string, GroupPost[]>>({})
  const cursorByGroup = ref<Record<string, string | null>>({})
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadPosts(groupId: string, cursor?: string): Promise<void> {
    isLoading.value = true
    error.value = null
    try {
      let url = `/admin/api/groups/${groupId}/posts?limit=20`
      if (cursor) {
        url += `&cursor=${cursor}`
      }
      const res = await axios.get(url)
      const posts: GroupPost[] = res.data.posts ?? []
      if (!cursor) {
        // First load — replace
        postsByGroup.value[groupId] = posts
      } else {
        // Subsequent — append
        if (!postsByGroup.value[groupId]) {
          postsByGroup.value[groupId] = []
        }
        postsByGroup.value[groupId] = [...postsByGroup.value[groupId], ...posts]
      }
      cursorByGroup.value[groupId] = res.data.nextCursor ?? null
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load posts'
    } finally {
      isLoading.value = false
    }
  }

  async function createPost(groupId: string, payload: CreatePostPayload): Promise<void> {
    error.value = null
    try {
      const res = await axios.post(`/admin/api/groups/${groupId}/posts`, payload)
      const newPost: GroupPost = res.data.post
      if (!postsByGroup.value[groupId]) {
        postsByGroup.value[groupId] = []
      }
      postsByGroup.value[groupId] = [newPost, ...postsByGroup.value[groupId]]
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to create post'
      throw err
    }
  }

  return {
    postsByGroup,
    cursorByGroup,
    isLoading,
    error,
    loadPosts,
    createPost,
  }
})
