import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useAllMembersDomain, type UnifiedMember } from '../domain/all-members.domain'

export interface FilterTag {
  category: 'name' | 'group' | 'status' | 'type'
  value: string
}

export const useMembersListUI = defineStore('members-list-ui', () => {
  const domain = useAllMembersDomain()

  const filterTags = ref<FilterTag[]>([])
  const searchQuery = ref('')
  const dismissedFailedGroups = ref(false)

  const filteredMembers = computed<UnifiedMember[]>(() => {
    if (filterTags.value.length === 0) return domain.allMembers

    return domain.allMembers.filter((member) => {
      return filterTags.value.every((tag) => {
        switch (tag.category) {
          case 'name':
            return member.name.toLowerCase().includes(tag.value.toLowerCase())
          case 'group':
            return member.groups.some(
              (g) => g.groupName.toLowerCase() === tag.value.toLowerCase(),
            )
          // TODO(Phase 14): Filter by activity data once available
          case 'status':
          case 'type':
            return true
          default:
            return true
        }
      })
    })
  })

  const hasActiveFilters = computed(() => filterTags.value.length > 0)

  function addFilter(category: FilterTag['category'], value: string): void {
    if (!value.trim()) return
    const exists = filterTags.value.some(
      (t) => t.category === category && t.value === value,
    )
    if (!exists) filterTags.value.push({ category, value })
    searchQuery.value = ''
  }

  function removeFilter(index: number): void {
    filterTags.value.splice(index, 1)
  }

  function clearFilters(): void {
    filterTags.value = []
    searchQuery.value = ''
  }

  function setSearchQuery(query: string): void {
    searchQuery.value = query
  }

  function dismissFailedGroups(): void {
    dismissedFailedGroups.value = true
  }

  return {
    filterTags,
    searchQuery,
    filteredMembers,
    hasActiveFilters,
    dismissedFailedGroups,
    addFilter,
    removeFilter,
    clearFilters,
    setSearchQuery,
    dismissFailedGroups,
  }
})
