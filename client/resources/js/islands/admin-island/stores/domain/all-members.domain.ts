import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useGroupsDomain } from './groups.domain'
import { useMembersDomain } from './members.domain'

export interface UnifiedMember {
  userId: string
  name: string
  avatarUrl?: string
  groups: Array<{ groupId: string; groupName: string; role: string; joinedAt: string }>
  lastActive: string // most recent joinedAt across all groups
}

export const useAllMembersDomain = defineStore('all-members-domain', () => {
  const groupsDomain = useGroupsDomain()
  const membersDomain = useMembersDomain()

  const isLoading = ref(false)
  const failedGroups = ref<Array<{ groupId: string; groupName: string }>>([])

  const allMembers = computed<UnifiedMember[]>(() => {
    const groupNameMap = new Map<string, string>(
      groupsDomain.groups.map((g) => [g.id, g.name]),
    )

    const memberMap = new Map<string, UnifiedMember>()

    for (const [groupId, members] of Object.entries(membersDomain.membersByGroup)) {
      const groupName = groupNameMap.get(groupId) ?? groupId
      for (const member of members) {
        const existing = memberMap.get(member.userId)
        if (existing) {
          existing.groups.push({
            groupId,
            groupName,
            role: member.role,
            joinedAt: member.joinedAt,
          })
          // Update lastActive if this joinedAt is more recent
          if (member.joinedAt > existing.lastActive) {
            existing.lastActive = member.joinedAt
          }
        } else {
          memberMap.set(member.userId, {
            userId: member.userId,
            name: member.name,
            avatarUrl: member.avatarUrl,
            groups: [{ groupId, groupName, role: member.role, joinedAt: member.joinedAt }],
            lastActive: member.joinedAt,
          })
        }
      }
    }

    return [...memberMap.values()]
  })

  async function loadAll(): Promise<void> {
    isLoading.value = true
    failedGroups.value = []

    if (groupsDomain.groups.length === 0) {
      await groupsDomain.loadGroups()
    }

    const groups = groupsDomain.groups
    const results = await Promise.allSettled(groups.map((g) => membersDomain.loadMembers(g.id)))

    for (let i = 0; i < results.length; i++) {
      if (results[i].status === 'rejected') {
        failedGroups.value.push({
          groupId: groups[i].id,
          groupName: groups[i].name,
        })
      }
    }

    isLoading.value = false
  }

  return { isLoading, failedGroups, allMembers, loadAll }
})
