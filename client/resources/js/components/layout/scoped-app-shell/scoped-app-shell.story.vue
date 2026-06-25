<script setup lang="ts">
import { ref } from 'vue'
import ScopedAppShell from './scoped-app-shell.vue'
import DeviceFrame from '../device-frame/device-frame.vue'

// Tabs declare who can see them. The "Edit" tab is contributor-only, so it
// disappears for a member scope; "Overview" and "Discussion" are always shown.
const tabs = [
  { key: 'overview', label: 'Overview' },
  { key: 'edit', label: 'Edit', visibleFor: ['contributor'] as ('member' | 'contributor')[] },
  { key: 'discussion', label: 'Discussion' },
]

const contributorScope = {
  type: 'program' as const,
  id: 42,
  role: 'contributor' as const,
  label: 'Romans (Program)',
}

const memberScope = {
  type: 'lesson' as const,
  id: 'd4',
  role: 'member' as const,
  label: 'Day 4 of Romans',
}

const activeContributor = ref('overview')
const activeMember = ref('overview')
</script>

<template>
  <Story title="Layouts/ScopedAppShell" :layout="{ type: 'grid', width: 460 }">
    <Variant title="Contributor scope">
      <DeviceFrame size="Md">
        <ScopedAppShell
          :scope="contributorScope"
          :tabs="tabs"
          :active-tab="activeContributor"
          @select-tab="activeContributor = $event"
        >
          <template #header>
            <strong>Romans Study</strong>
          </template>
          <template #default="{ readonly }">
            <div style="padding: var(--space-lg)">
              <p>Contributor can edit within scope.</p>
              <p>readonly = {{ readonly }}</p>
              <p>The "Edit" tab is visible below.</p>
            </div>
          </template>
        </ScopedAppShell>
      </DeviceFrame>
    </Variant>

    <Variant title="Member scope (read-only)">
      <DeviceFrame size="Md">
        <ScopedAppShell
          :scope="memberScope"
          :tabs="tabs"
          :active-tab="activeMember"
          @select-tab="activeMember = $event"
        >
          <template #header>
            <strong>Romans Study</strong>
          </template>
          <template #default="{ readonly }">
            <div style="padding: var(--space-lg)">
              <p>Member is view-only.</p>
              <p>readonly = {{ readonly }}</p>
              <p>The "Edit" tab is hidden below.</p>
            </div>
          </template>
        </ScopedAppShell>
      </DeviceFrame>
    </Variant>
  </Story>
</template>
