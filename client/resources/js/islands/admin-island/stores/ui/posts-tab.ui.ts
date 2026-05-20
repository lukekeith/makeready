import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRoute } from 'vue-router'
import { usePostsDomain, type PostType, type CreatePostPayload } from '../domain/posts.domain'

export const usePostsTabUI = defineStore('posts-tab-ui', () => {
  const domain = usePostsDomain()
  const route = useRoute()

  // UI state
  const isCreateFormOpen = ref(false)
  const selectedType = ref<PostType>('ANNOUNCEMENT')
  const formError = ref<string | null>(null)
  const isSaving = ref(false)

  // Form fields — one ref per field for type-conditional rendering
  const formTitle = ref('')
  const formContent = ref('')
  const formVideoUrl = ref('')
  const formEventDate = ref('')
  const formEventLocation = ref('')
  const pollOptions = ref<string[]>(['', ''])

  // Computed
  const groupId = computed(() => route.params.id as string)

  const posts = computed(() => domain.postsByGroup[groupId.value] ?? [])

  const hasMore = computed(() => !!domain.cursorByGroup[groupId.value])

  const isLoading = computed(() => domain.isLoading)

  // Methods
  async function loadData(): Promise<void> {
    const id = groupId.value
    if (!id) return
    await domain.loadPosts(id)
  }

  async function loadMore(): Promise<void> {
    const id = groupId.value
    const cursor = domain.cursorByGroup[id]
    if (!id || !cursor) return
    await domain.loadPosts(id, cursor)
  }

  function openCreate(): void {
    formTitle.value = ''
    formContent.value = ''
    formVideoUrl.value = ''
    formEventDate.value = ''
    formEventLocation.value = ''
    pollOptions.value = ['', '']
    selectedType.value = 'ANNOUNCEMENT'
    formError.value = null
    isCreateFormOpen.value = true
  }

  function closeCreate(): void {
    isCreateFormOpen.value = false
  }

  function addPollOption(): void {
    pollOptions.value.push('')
  }

  function removePollOption(index: number): void {
    if (pollOptions.value.length <= 2) return
    pollOptions.value.splice(index, 1)
  }

  function buildPayload(): CreatePostPayload {
    const type = selectedType.value
    switch (type) {
      case 'ANNOUNCEMENT':
        return {
          type,
          content: formContent.value,
          title: formTitle.value || undefined,
        }
      case 'POLL':
        return {
          type,
          content: formContent.value,
          pollOptions: pollOptions.value.filter((o) => o.trim()),
        }
      case 'EVENT':
        return {
          type,
          content: formContent.value,
          title: formTitle.value || undefined,
          eventDate: formEventDate.value
            ? new Date(formEventDate.value).toISOString()
            : undefined,
          eventLocation: formEventLocation.value || undefined,
        }
      case 'VIDEO':
        return {
          type,
          content: formContent.value,
          title: formTitle.value || undefined,
          videoUrl: formVideoUrl.value,
        }
      default:
        return {
          type,
          content: formContent.value,
          title: formTitle.value || undefined,
        }
    }
  }

  async function submitCreate(): Promise<void> {
    isSaving.value = true
    formError.value = null
    try {
      const payload = buildPayload()
      await domain.createPost(groupId.value, payload)
      closeCreate()
    } catch (err: any) {
      formError.value = err?.response?.data?.message ?? 'Failed to create post'
    } finally {
      isSaving.value = false
    }
  }

  return {
    isCreateFormOpen,
    selectedType,
    formError,
    isSaving,
    formTitle,
    formContent,
    formVideoUrl,
    formEventDate,
    formEventLocation,
    pollOptions,
    groupId,
    posts,
    hasMore,
    isLoading,
    loadData,
    loadMore,
    openCreate,
    closeCreate,
    addPollOption,
    removePollOption,
    buildPayload,
    submitCreate,
  }
})
