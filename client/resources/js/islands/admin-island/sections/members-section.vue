<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useAllMembersDomain } from '../stores/domain/all-members.domain'
import { useMembersListUI } from '../stores/ui/members-list.ui'
import { useGroupsDomain } from '../stores/domain/groups.domain'
import { useMemberDetailUI } from '../stores/ui/member-detail.ui'
import AdminVirtualTable from '../../../components/admin/admin-virtual-table/admin-virtual-table.vue'
import MemberFilterBar from '../../../components/admin/member-filter-bar/member-filter-bar.vue'
import MemberProfileDrawer from '../../../components/admin/member-profile-drawer/member-profile-drawer.vue'
import Button from 'primevue/button'
import Card from 'primevue/card'
import Message from 'primevue/message'

const allMembersDomain = useAllMembersDomain()
const membersListUI = useMembersListUI()
const groupsDomain = useGroupsDomain()
const memberDetailUI = useMemberDetailUI()

const availableGroups = computed(() => groupsDomain.groups.map((g) => g.name))
onMounted(() => { allMembersDomain.loadAll() })
function handleRowClick(userId: string): void { memberDetailUI.openDrawer(userId) }
</script>

<template>
  <div style="display: flex; flex-direction: column; gap: 1.5rem;">
    <div style="display: flex; align-items: center; justify-content: space-between;">
      <h1 style="font-size: 1.5rem; font-weight: 700; margin: 0;">Members</h1>
      <span v-if="!allMembersDomain.isLoading" style="font-size: 0.875rem; color: var(--p-text-muted-color);">{{ allMembersDomain.allMembers.length }} total</span>
    </div>

    <Message
      v-if="allMembersDomain.failedGroups.length > 0 && !membersListUI.dismissedFailedGroups"
      severity="warn"
      @close="membersListUI.dismissFailedGroups()"
    >
      Could not load members from: {{ allMembersDomain.failedGroups.map((g) => g.groupName).join(', ') }}. Other members are shown below.
    </Message>

    <MemberFilterBar
      :filter-tags="membersListUI.filterTags"
      :search-query="membersListUI.searchQuery"
      :available-groups="availableGroups"
      :has-active-filters="membersListUI.hasActiveFilters"
      @add-filter="membersListUI.addFilter"
      @remove-filter="membersListUI.removeFilter"
      @clear-filters="membersListUI.clearFilters"
      @update:search-query="membersListUI.setSearchQuery"
    />

    <AdminVirtualTable
      v-if="membersListUI.filteredMembers.length > 0 || allMembersDomain.isLoading"
      :data="membersListUI.filteredMembers"
      :is-loading="allMembersDomain.isLoading"
      @row-click="handleRowClick"
    />

    <Card v-else-if="membersListUI.hasActiveFilters && membersListUI.filteredMembers.length === 0">
      <template #content>
        <div style="text-align: center; padding: 1rem;">
          <p style="font-weight: 500;">No members match your filters</p>
          <Button label="Clear filters" severity="secondary" outlined size="small" @click="membersListUI.clearFilters()" />
        </div>
      </template>
    </Card>

    <Card v-else-if="!allMembersDomain.isLoading && allMembersDomain.allMembers.length === 0">
      <template #content>
        <div style="text-align: center; padding: 1rem;">
          <p style="font-weight: 500;">No members yet</p>
          <p style="color: var(--p-text-muted-color);">Members will appear here once people join your groups.</p>
        </div>
      </template>
    </Card>

    <MemberProfileDrawer />
  </div>
</template>
