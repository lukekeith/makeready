import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRoute } from 'vue-router'
import { useGroupsDomain } from '../domain/groups.domain'

export const useGroupDetailUI = defineStore('group-detail-ui', () => {
  const domain = useGroupsDomain()
  const route = useRoute()

  const activeTab = ref('settings')
  const isSavingSettings = ref(false)
  const isUploadingCover = ref(false)
  const settingsError = ref<string | null>(null)

  const currentGroup = computed(() => {
    const id = route.params.id as string | undefined
    if (!id) return undefined
    return domain.groups.find((g) => g.id === id)
  })

  const settingsFormValues = computed(() => {
    const g = currentGroup.value
    if (!g) return {}
    return {
      name: g.name ?? '',
      description: g.description ?? '',
      welcomeMessage: g.welcomeMessage ?? '',
      isPrivate: g.isPrivate ?? false,
      allowInvites: g.allowInvites ?? false,
      memberDirectory: g.memberDirectory ?? false,
      maxMembers: g.maxMembers ?? null,
    }
  })

  const settingsFields = computed(() => [
    {
      key: 'name',
      label: 'Group Name',
      type: 'text' as const,
      required: true,
      placeholder: 'Enter group name',
    },
    {
      key: 'description',
      label: 'Description',
      type: 'textarea' as const,
      placeholder: 'Describe this group (optional)',
    },
    {
      key: 'welcomeMessage',
      label: 'Welcome Message',
      type: 'textarea' as const,
      placeholder: 'Message shown to new members',
    },
    {
      key: 'isPrivate',
      label: 'Private Group',
      type: 'toggle' as const,
    },
    {
      key: 'allowInvites',
      label: 'Allow Member Invites',
      type: 'toggle' as const,
    },
    {
      key: 'memberDirectory',
      label: 'Member Directory',
      type: 'toggle' as const,
    },
    {
      key: 'maxMembers',
      label: 'Max Members',
      type: 'number' as const,
      placeholder: 'Leave empty for unlimited',
    },
  ])

  const pageTitle = computed(() => currentGroup.value?.name ?? 'Group Detail')

  return {
    activeTab,
    isSavingSettings,
    isUploadingCover,
    settingsError,
    currentGroup,
    settingsFormValues,
    settingsFields,
    pageTitle,
  }
})
