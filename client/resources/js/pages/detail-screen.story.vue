<script setup lang="ts">
import '../../css/app.scss'

import { ref } from 'vue'
import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import AppShell from '../components/layout/app-shell/app-shell.vue'
import PageHeader from '../components/navigation/page-header/page-header.vue'
import IconButton from '../components/primitive/icon-button/icon-button.vue'
import TabSlider from '../components/navigation/tab-slider/tab-slider.vue'
import CardActivity from '../components/card/card-activity/card-activity.vue'
import List from '../components/layout/list/list.vue'
import CardMember from '../components/card/card-member/card-member.vue'
import Grid from '../components/layout/grid/grid.vue'
import CardStudy from '../components/card/card-study/card-study.vue'

// --- mock data ---------------------------------------------------------------
const tab = ref('posts')
const sliderTabs = [
  { key: 'posts', label: 'Posts' },
  { key: 'members', label: 'Members' },
  { key: 'studies', label: 'Studies' },
]

const postIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>'
const checkIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>'

const posts = [
  { text: 'MakeReady started the Romans in 30 days program. Get ready!', timestamp: '2d ago', icon: postIcon },
  { text: 'Maria shared a reflection on Day 12 SOAP entry', timestamp: '4h ago', icon: postIcon },
  { text: 'James completed Romans Day 12', timestamp: '1h ago', icon: checkIcon },
]

const members = [
  { id: 1, name: 'Luke Keith', role: 'Group Leader', meta: 'Joined Mar 18', initials: 'LK', avatarUrl: 'https://i.pravatar.cc/96?img=12' },
  { id: 2, name: 'Maria Lopez', role: 'Member', meta: 'Joined Mar 20', initials: 'ML', avatarUrl: 'https://i.pravatar.cc/96?img=5' },
  { id: 3, name: 'James Chen', role: 'Member', meta: 'Joined Apr 2', initials: 'JC', avatarUrl: 'https://i.pravatar.cc/96?img=8' },
  { id: 4, name: 'Aisha Patel', role: 'Member', pending: true, initials: 'AP', avatarUrl: '' },
]

const bookIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5z"/></svg>'

const studies = [
  { id: 'romans', title: 'Romans in 30 days', coverUrl: 'https://picsum.photos/seed/romans/240/360' },
  { id: 'exodus', title: 'Through Exodus', coverUrl: 'https://picsum.photos/seed/exodus/240/360' },
  { id: 'psalms', title: 'Psalms of Ascent', coverUrl: 'https://picsum.photos/seed/psalms/240/360' },
  { id: 'james', title: 'Faith & Works: James', coverUrl: 'https://picsum.photos/seed/james/240/360' },
]

const backIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18 9 12l6-6"/></svg>'
const menuIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/></svg>'
</script>

<template>
  <Story title="Pages/Detail Screen" group="pages" :layout="{ type: 'single' }">
    <Variant title="Group home">
      <DeviceFrame size="Md">
        <AppShell>
          <template #header>
            <PageHeader title="Young Professionals">
              <template #leading>
                <IconButton aria-label="Go back" variant="Blur">
                  <span v-html="backIcon" />
                </IconButton>
              </template>
              <template #actions>
                <IconButton aria-label="Group menu" variant="Blur">
                  <span v-html="menuIcon" />
                </IconButton>
              </template>
            </PageHeader>
          </template>

          <div class="DetailScreen">
            <div class="DetailScreen__tabs">
              <TabSlider v-model="tab" :tabs="sliderTabs" />
            </div>

            <!-- Posts -->
            <div v-if="tab === 'posts'" class="DetailScreen__panel">
              <CardActivity
                v-for="(post, i) in posts"
                :key="i"
                :text="post.text"
                :timestamp="post.timestamp"
                :icon="post.icon"
              />
            </div>

            <!-- Members -->
            <div v-else-if="tab === 'members'" class="DetailScreen__panel">
              <List>
                <CardMember
                  v-for="member in members"
                  :key="member.id"
                  :name="member.name"
                  :role="member.role"
                  :meta="member.meta"
                  :initials="member.initials"
                  :avatar-url="member.avatarUrl"
                  :pending="member.pending"
                />
              </List>
            </div>

            <!-- Studies -->
            <div v-else class="DetailScreen__panel">
              <Grid cols="2" gap="Md">
                <CardStudy
                  v-for="study in studies"
                  :key="study.id"
                  :title="study.title"
                  :cover-url="study.coverUrl"
                  size="Mini"
                />
              </Grid>
            </div>
          </div>
        </AppShell>
      </DeviceFrame>
    </Variant>
  </Story>
</template>

<style scoped>
.DetailScreen {
  display: flex;
  flex-direction: column;
  gap: var(--space-4, 16px);
  padding: var(--space-4, 16px);
}

.DetailScreen__panel {
  display: flex;
  flex-direction: column;
  gap: var(--space-2, 8px);
}
</style>
