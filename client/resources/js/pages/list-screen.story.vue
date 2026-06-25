<script setup lang="ts">
import '../../css/app.scss'

import { ref } from 'vue'
import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import AppShell from '../components/layout/app-shell/app-shell.vue'
import PageHeader from '../components/navigation/page-header/page-header.vue'
import SearchField from '../components/form/search-field/search-field.vue'
import FilterChipDropdown from '../components/navigation/filter-chip-dropdown/filter-chip-dropdown.vue'
import List from '../components/layout/list/list.vue'
import SwipeableCard from '../components/card/swipeable-card/swipeable-card.vue'
import SlideButton from '../components/card/slide-button/slide-button.vue'
import CardGroup from '../components/card/card-group/card-group.vue'
import Fab from '../components/navigation/fab/fab.vue'
import TabBar, { type TabBarTab } from '../components/navigation/tab-bar/tab-bar.vue'

// --- mock data ---------------------------------------------------------------
const query = ref('')

const sort = ref('recent')
const sortOptions = [
  { value: 'recent', label: 'Recently active' },
  { value: 'name', label: 'Name' },
  { value: 'size', label: 'Member count' },
]

const groups = [
  { id: 'yp', name: 'Young Professionals', initials: 'YP', imageUrl: 'https://picsum.photos/seed/yp/144', memberCount: 24, meta: 'Day 12' },
  { id: 'sm', name: 'Sunday Morning', initials: 'SM', imageUrl: 'https://picsum.photos/seed/sm/144', memberCount: 38, meta: 'Day 4' },
  { id: 'cm', name: 'College Ministry', initials: 'CM', imageUrl: 'https://picsum.photos/seed/cm/144', memberCount: 16, meta: 'Day 28' },
  { id: 'wb', name: "Women's Bible Study", initials: 'WB', imageUrl: 'https://picsum.photos/seed/wb/144', memberCount: 21, meta: 'Day 7' },
  { id: 'mg', name: "Men's Group", initials: 'MG', imageUrl: 'https://picsum.photos/seed/mg/144', memberCount: 14, meta: 'Day 19' },
]

const editIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4z"/></svg>'
const deleteIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>'

const tabs: TabBarTab[] = [
  { key: 'home', label: 'Home' },
  { key: 'groups', label: 'Groups' },
  { key: 'library', label: 'Library' },
  { key: 'profile', label: 'Profile' },
]

const tabIcons: Record<string, string> = {
  home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/></svg>',
  groups: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  library: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>',
  profile: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
}

const plusIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>'
</script>

<template>
  <Story title="Pages/List Screen" group="pages" :layout="{ type: 'single' }">
    <Variant title="Groups">
      <DeviceFrame size="Md">
        <AppShell>
          <template #header>
            <PageHeader title="Groups" />
          </template>

          <div class="ListScreen">
            <div class="ListScreen__search">
              <SearchField v-model="query" placeholder="Search groups" />
            </div>

            <div class="ListScreen__filters">
              <FilterChipDropdown
                v-model="sort"
                label="Sort"
                :options="sortOptions"
              />
            </div>

            <List :dividers="false">
              <SwipeableCard v-for="group in groups" :key="group.id">
                <CardGroup
                  :name="group.name"
                  :initials="group.initials"
                  :image-url="group.imageUrl"
                  :member-count="group.memberCount"
                  :meta="group.meta"
                />
                <template #actions>
                  <SlideButton style="Neutral" label="Edit">
                    <template #icon><span v-html="editIcon" /></template>
                  </SlideButton>
                  <SlideButton style="Destructive" label="Delete">
                    <template #icon><span v-html="deleteIcon" /></template>
                  </SlideButton>
                </template>
              </SwipeableCard>
            </List>
          </div>

          <template #fab>
            <Fab aria-label="Add group" position="BottomRight">
              <span v-html="plusIcon" />
            </Fab>
          </template>

          <template #tabbar>
            <TabBar :tabs="tabs" active="groups">
              <template #icon="{ tab }">
                <span v-html="tabIcons[tab.key]" />
              </template>
            </TabBar>
          </template>
        </AppShell>
      </DeviceFrame>
    </Variant>
  </Story>
</template>

<style scoped>
.ListScreen {
  display: flex;
  flex-direction: column;
  gap: var(--space-3, 12px);
  padding: var(--space-4, 16px);
}

.ListScreen__filters {
  display: flex;
  gap: var(--space-2, 8px);
}
</style>
