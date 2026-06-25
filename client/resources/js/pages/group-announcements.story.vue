<script setup lang="ts">
// SC-4 PROOF SCREEN (PRD §3). A representative new group-leader screen —
// "Group Announcements" — assembled end-to-end from the EXISTING catalog with
// ZERO new components (0 new primitives, 0 new domain components). This
// validates the north-star goal: new screens are composed, not designed.
//
// Components used (all pre-existing): DeviceFrame, AppShell, PageHeader, TabBar,
// Fab, Page, Section, CardPost, EmptyState, Avatar, Button.
import { ref } from 'vue'
import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import AppShell from '../components/layout/app-shell/app-shell.vue'
import Page from '../components/layout/page/page.vue'
import Section from '../components/layout/section/section.vue'
import PageHeader from '../components/navigation/page-header/page-header.vue'
import TabBar from '../components/navigation/tab-bar/tab-bar.vue'
import Fab from '../components/navigation/fab/fab.vue'
import CardPost from '../components/card/card-post/card-post.vue'
import EmptyState from '../components/primitive/empty-state/empty-state.vue'
import Avatar from '../components/primitive/avatar/avatar.vue'
import Button from '../components/primitive/button/button.vue'

const tab = ref('groups')
const tabs = [
  { key: 'home', label: 'Home' },
  { key: 'groups', label: 'Groups' },
  { key: 'library', label: 'Library' },
  { key: 'calendar', label: 'Calendar' },
  { key: 'search', label: 'Search' },
]

const announcements = [
  { id: '1', author: 'Sarah Chen', timestamp: '2h ago', body: "Reminder: we're meeting at the coffee shop this Thursday instead of the usual room. See you at 7!" },
  { id: '2', author: 'Sarah Chen', timestamp: 'Yesterday', body: 'Great discussion last night on Romans 8. I posted the reflection questions for Day 5 — take a look before we gather.', mediaUrl: '/images/image-03.png' },
  { id: '3', author: 'Marcus Lee', timestamp: '3 days ago', body: 'Welcome to our two new members, Priya and Jordan! 🎉' },
]

const tabIcon = (key: string) => ({
  home: 'M3 10.5 12 3l9 7.5M5 9.5V21h14V9.5',
  groups: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z',
  library: 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2Z',
  calendar: 'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z',
  search: 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm10 2-4.35-4.35',
}[key] ?? '')
</script>

<template>
  <Story title="Pages/Group Announcements (SC-4)" :layout="{ type: 'single' }">
    <Variant title="Populated">
      <DeviceFrame size="Md">
        <AppShell>
          <template #header>
            <PageHeader title="Announcements">
              <template #leading>
                <button class="back" aria-label="Back">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="m15 18-6-6 6-6" /></svg>
                </button>
              </template>
              <template #actions><Avatar initials="LK" size="Sm" /></template>
            </PageHeader>
          </template>

          <Page :padded="false" style="padding-top: var(--space-md);">
            <Section title="Pinned" style="padding: 0 var(--page-pad-x) var(--space-md);">
              <CardPost
                author="Sarah Chen"
                timestamp="Pinned"
                body="Our group covenant is in the Library — please read it before week 2."
              />
            </Section>
            <Section title="Recent" style="padding: 0 var(--page-pad-x);">
              <div class="feed">
                <CardPost
                  v-for="a in announcements"
                  :key="a.id"
                  :author="a.author"
                  :timestamp="a.timestamp"
                  :body="a.body"
                  :media-url="a.mediaUrl"
                />
              </div>
            </Section>
          </Page>

          <template #fab>
            <Fab label="Post" aria-label="New announcement">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14" /></svg>
            </Fab>
          </template>

          <template #tabbar>
            <TabBar v-model="tab" :tabs="tabs">
              <template #icon="{ tab: t, active }">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" :style="{ width: 'var(--icon-md)', height: 'var(--icon-md)', opacity: active ? 1 : 0.7 }"><path :d="tabIcon(t.key)" /></svg>
              </template>
            </TabBar>
          </template>
        </AppShell>
      </DeviceFrame>
    </Variant>

    <Variant title="Empty">
      <DeviceFrame size="Md">
        <AppShell>
          <template #header>
            <PageHeader title="Announcements" />
          </template>
          <Page style="display: grid; place-items: center; min-height: 70vh;">
            <EmptyState
              align="Center"
              title="No announcements yet"
              description="Post an update to keep your group in the loop."
            >
              <template #icon>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" style="width: var(--icon-lg); height: var(--icon-lg)"><path d="M3 8l9 6 9-6M5 5h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z" /></svg>
              </template>
              <template #action>
                <Button variant="Primary" mode="Action" size="Default">New announcement</Button>
              </template>
            </EmptyState>
          </Page>
        </AppShell>
      </DeviceFrame>
    </Variant>
  </Story>
</template>

<style scoped>
.feed { display: flex; flex-direction: column; gap: var(--space-md); }
.back {
  display: inline-flex; align-items: center; justify-content: center;
  width: var(--touch-min); height: var(--touch-min);
  background: transparent; border: 0; color: var(--fg-primary); cursor: pointer;
}
.back svg { width: var(--icon-md); height: var(--icon-md); }
</style>
