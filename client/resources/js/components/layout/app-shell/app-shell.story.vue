<script setup lang="ts">
import { ref } from 'vue'
import AppShell from './app-shell.vue'
import DeviceFrame from '../device-frame/device-frame.vue'
import PageHeader from '../../navigation/page-header/page-header.vue'
import TabBar from '../../navigation/tab-bar/tab-bar.vue'
import Fab from '../../navigation/fab/fab.vue'
import Section from '../section/section.vue'
import List from '../list/list.vue'
import ListItem from '../list-item/list-item.vue'
import Avatar from '../../primitive/avatar/avatar.vue'
import Badge from '../../primitive/badge/badge.vue'
import Text from '../../primitive/text/text.vue'

const tab = ref('groups')
const tabs = [
  { key: 'home', label: 'Home' },
  { key: 'groups', label: 'Groups' },
  { key: 'library', label: 'Library' },
  { key: 'calendar', label: 'Calendar' },
  { key: 'search', label: 'Search' },
]

const groups = [
  { id: '1', name: 'Young Professionals', meta: '27 members · Day 4', initials: 'YP' },
  { id: '2', name: 'Sunday Morning Study', meta: '14 members · Day 1', initials: 'SM' },
  { id: '3', name: 'Womens Bible Study', meta: '32 members · Day 9', initials: 'WB' },
]

function iconFor(key: string) {
  // Minimal inline glyphs per tab (placeholder Lucide-style paths).
  const paths: Record<string, string> = {
    home: 'M3 10.5 12 3l9 7.5M5 9.5V21h14V9.5',
    groups: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm14 10v-2a4 4 0 0 0-3-3.87M16 3.13A4 4 0 0 1 16 11',
    library: 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2Z',
    calendar: 'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z',
    search: 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm10 2-4.35-4.35',
  }
  return paths[key] ?? ''
}
</script>

<template>
  <Story title="Layouts/App Shell" :layout="{ type: 'single' }">
    <Variant title="Groups screen">
      <DeviceFrame size="Md">
        <AppShell>
          <!-- Sticky frosted header with tab switcher + actions -->
          <template #header>
            <PageHeader title="Groups">
              <template #actions>
                <Avatar initials="LK" size="Sm" />
              </template>
            </PageHeader>
          </template>

          <!-- Scrollable content -->
          <Section title="Your groups" style="padding: var(--space-lg) 0;">
            <List :dividers="true" inset style="margin: 0 var(--page-pad-x);">
              <ListItem
                v-for="g in groups"
                :key="g.id"
                :title="g.name"
                :subtitle="g.meta"
                interactive
              >
                <template #leading><Avatar :initials="g.initials" size="Md" /></template>
                <template #trailing><Badge tone="Primary" size="Sm">Active</Badge></template>
              </ListItem>
            </List>

            <div style="padding: var(--space-2xl) var(--page-pad-x); text-align: center;">
              <Text variant="Caption" tone="Tertiary">Pull to refresh · 3 groups</Text>
            </div>
          </Section>

          <!-- Floating add button -->
          <template #fab>
            <Fab aria-label="Create group" @click="() => {}">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14" /></svg>
            </Fab>
          </template>

          <!-- Bottom tab bar -->
          <template #tabbar>
            <TabBar v-model="tab" :tabs="tabs">
              <template #icon="{ tab: t, active }">
                <svg viewBox="0 0 24 24" fill="none" :stroke="active ? 'currentColor' : 'currentColor'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width: var(--icon-md); height: var(--icon-md);">
                  <path :d="iconFor(t.key)" />
                </svg>
              </template>
            </TabBar>
          </template>
        </AppShell>
      </DeviceFrame>
    </Variant>
  </Story>
</template>
