<script setup lang="ts">
import '../../css/app.scss'
import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import PageHeader from '../components/navigation/page-header/page-header.vue'
import Page from '../components/layout/page/page.vue'
import SharedContentList, {
  type SharedGroup,
} from '../components/invite/shared-content-list/shared-content-list.vue'

// ── Mock data ────────────────────────────────────────────────────────────────
// Grouped shared content: a Programs group and a Lessons group, each with a
// couple of items (title, inviter, role, scope).
const groups: SharedGroup[] = [
  {
    key: 'programs',
    title: 'Programs',
    items: [
      {
        id: 'romans',
        title: 'Romans in 30 days',
        inviterName: 'Sarah Chen',
        role: 'contributor',
        scopeType: 'program',
        scopeLabel: 'Entire program',
      },
      {
        id: 'psalms',
        title: 'Psalms of Ascent',
        inviterName: 'Marcus Reed',
        role: 'member',
        scopeType: 'program',
        scopeLabel: 'Entire program',
      },
    ],
  },
  {
    key: 'lessons',
    title: 'Lessons',
    items: [
      {
        id: 'rom-4',
        title: 'Romans 4 — Faith of Abraham',
        inviterName: 'Sarah Chen',
        role: 'contributor',
        scopeType: 'lesson',
        scopeLabel: 'Day 4 of Romans',
      },
      {
        id: 'ps-121',
        title: 'Psalm 121',
        inviterName: 'Marcus Reed',
        role: 'member',
        scopeType: 'lesson',
        scopeLabel: 'Day 2 of Psalms',
      },
    ],
  },
]

const emptyGroups: SharedGroup[] = [
  { key: 'programs', title: 'Programs', items: [] },
  { key: 'lessons', title: 'Lessons', items: [] },
]
</script>

<template>
  <Story title="Pages/Shared With Me" :layout="{ type: 'single' }">
    <Variant title="With shared content">
      <DeviceFrame size="Md">
        <div class="SharedWithMe">
          <PageHeader title="Shared with me" />
          <Page class="SharedWithMe__body">
            <SharedContentList :groups="groups" />
          </Page>
        </div>
      </DeviceFrame>
    </Variant>

    <Variant title="Empty state">
      <DeviceFrame size="Md">
        <div class="SharedWithMe">
          <PageHeader title="Shared with me" />
          <Page class="SharedWithMe__body">
            <SharedContentList :groups="emptyGroups" />
          </Page>
        </div>
      </DeviceFrame>
    </Variant>
  </Story>
</template>

<style scoped>
.SharedWithMe {
  display: flex;
  flex-direction: column;
  min-height: 100%;
  background: var(--bg-canvas);
}
.SharedWithMe__body {
  flex: 1;
  padding-top: var(--space-md);
  padding-bottom: var(--space-xl);
}
</style>
