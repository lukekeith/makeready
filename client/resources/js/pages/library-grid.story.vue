<script setup lang="ts">
import '../../css/app.scss'

import { ref, computed } from 'vue'
import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import AppShell from '../components/layout/app-shell/app-shell.vue'
import PageHeader from '../components/navigation/page-header/page-header.vue'
import FilterChipDropdown from '../components/navigation/filter-chip-dropdown/filter-chip-dropdown.vue'
import Grid from '../components/layout/grid/grid.vue'
import CardStudy from '../components/card/card-study/card-study.vue'
import CardVideo from '../components/card/card-video/card-video.vue'
import TabBar, { type TabBarTab } from '../components/navigation/tab-bar/tab-bar.vue'

// --- mock data ---------------------------------------------------------------
const headerTabs = ['Programs', 'Media']
const activeTab = ref('Programs')

const sort = ref('recent')
const sortOptions = [
  { value: 'recent', label: 'Recently added' },
  { value: 'title', label: 'Title' },
  { value: 'popular', label: 'Most used' },
]

const programs = [
  { id: 'romans', title: 'Romans in 30 days', coverUrl: 'https://picsum.photos/seed/romans/240/360' },
  { id: 'exodus', title: 'Through Exodus', coverUrl: 'https://picsum.photos/seed/exodus/240/360' },
  { id: 'psalms', title: 'Psalms of Ascent', coverUrl: 'https://picsum.photos/seed/psalms/240/360' },
  { id: 'james', title: 'Faith & Works: James', coverUrl: 'https://picsum.photos/seed/james/240/360' },
  { id: 'john', title: 'The Gospel of John', coverUrl: 'https://picsum.photos/seed/john/240/360' },
  { id: 'acts', title: 'Acts: The Early Church', coverUrl: 'https://picsum.photos/seed/acts/240/360' },
]

const media = [
  { id: 'v1', title: 'Welcome to the study', category: 'Intro', duration: '2:14', thumbUrl: 'https://picsum.photos/seed/v1/320/200' },
  { id: 'v2', title: 'How to do a SOAP entry', category: 'Tutorial', duration: '5:42', thumbUrl: 'https://picsum.photos/seed/v2/320/200' },
  { id: 'v3', title: 'Leading a group discussion', category: 'Leaders', duration: '8:30', thumbUrl: 'https://picsum.photos/seed/v3/320/200' },
  { id: 'v4', title: 'Romans overview', category: 'Teaching', duration: '12:04', thumbUrl: 'https://picsum.photos/seed/v4/320/200' },
  { id: 'v5', title: 'Prayer & reflection', category: 'Devotional', duration: '4:18', thumbUrl: 'https://picsum.photos/seed/v5/320/200' },
  { id: 'v6', title: 'Closing the week', category: 'Devotional', duration: '3:51', thumbUrl: 'https://picsum.photos/seed/v6/320/200' },
]

const showPrograms = computed(() => activeTab.value === 'Programs')

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
</script>

<template>
  <Story title="Pages/Library Grid" group="pages" :layout="{ type: 'single' }">
    <Variant title="Library">
      <DeviceFrame size="Md">
        <AppShell>
          <template #header>
            <PageHeader :tabs="headerTabs" v-model:active-tab="activeTab" />
          </template>

          <div class="LibraryGrid">
            <div class="LibraryGrid__sort">
              <FilterChipDropdown v-model="sort" label="Sort" :options="sortOptions" />
            </div>

            <Grid v-if="showPrograms" cols="2" gap="Md">
              <CardStudy
                v-for="program in programs"
                :key="program.id"
                :title="program.title"
                :cover-url="program.coverUrl"
                size="Mini"
              />
            </Grid>

            <Grid v-else cols="1" gap="Md">
              <CardVideo
                v-for="item in media"
                :key="item.id"
                :title="item.title"
                :description="item.category"
                status="confirmed"
                :image-style="{ kind: 'photo' }"
                :metadata="item.duration ? [{ value: item.duration }] : []"
              />
            </Grid>
          </div>

          <template #tabbar>
            <TabBar :tabs="tabs" active="library">
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
.LibraryGrid {
  display: flex;
  flex-direction: column;
  gap: var(--space-4, 16px);
  padding: var(--space-4, 16px);
}

.LibraryGrid__sort {
  display: flex;
  gap: var(--space-2, 8px);
}
</style>
