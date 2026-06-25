<script setup lang="ts">
import '../../css/app.scss'
import { ref } from 'vue'
import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import PageHeader from '../components/navigation/page-header/page-header.vue'
import Page from '../components/layout/page/page.vue'
import Section from '../components/layout/section/section.vue'
import Button from '../components/primitive/button/button.vue'
import RoleSelector from '../components/invite/role-selector/role-selector.vue'
import InviteScopeSelector from '../components/invite/invite-scope-selector/invite-scope-selector.vue'
import InviteSheet from '../components/invite/invite-sheet/invite-sheet.vue'

// ── Mock data ────────────────────────────────────────────────────────────────
type Role = 'member' | 'contributor'
type Scope = { type: 'program' | 'lesson'; id: string | number }

const role = ref<Role>('contributor')
const scope = ref<Scope | null>({ type: 'lesson', id: 'rom-4' })

const programs = [
  {
    id: 'romans',
    title: 'Romans in 30 days',
    lessons: [
      { id: 'rom-3', title: 'Romans 3 — Righteousness', dayLabel: 'Day 3' },
      { id: 'rom-4', title: 'Romans 4 — Faith of Abraham', dayLabel: 'Day 4' },
      { id: 'rom-5', title: 'Romans 5 — Peace with God', dayLabel: 'Day 5' },
    ],
  },
  {
    id: 'psalms',
    title: 'Psalms of Ascent',
    lessons: [
      { id: 'ps-120', title: 'Psalm 120', dayLabel: 'Day 1' },
      { id: 'ps-121', title: 'Psalm 121', dayLabel: 'Day 2' },
    ],
  },
]

// InviteSheet open state — local ref (no store needed).
const sheetOpen = ref(false)

const inviteCode = 'RMN-4K8'
const inviteUrl = 'https://makeready.app/i/RMN-4K8'
const qrSrc =
  'data:image/svg+xml;utf8,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 7 7" shape-rendering="crispEdges">' +
      '<rect width="7" height="7" fill="#fff"/>' +
      '<g fill="#6C47FF">' +
      '<rect x="0" y="0" width="3" height="1"/><rect x="0" y="0" width="1" height="3"/>' +
      '<rect x="2" y="2" width="1" height="1"/><rect x="4" y="0" width="1" height="1"/>' +
      '<rect x="6" y="0" width="1" height="3"/><rect x="4" y="2" width="2" height="1"/>' +
      '<rect x="0" y="4" width="1" height="3"/><rect x="2" y="4" width="3" height="1"/>' +
      '<rect x="6" y="4" width="1" height="1"/><rect x="3" y="6" width="1" height="1"/>' +
      '<rect x="5" y="5" width="2" height="2"/>' +
      '</g></svg>'
  )

function createInvite() {
  sheetOpen.value = true
}
</script>

<template>
  <Story title="Pages/Invite Flow" :layout="{ type: 'single' }">
    <DeviceFrame size="Md">
      <div class="InviteFlow">
        <PageHeader title="Invite" />

        <Page class="InviteFlow__body">
          <Section title="Role">
            <RoleSelector v-model="role" />
          </Section>

          <Section title="What to share">
            <InviteScopeSelector v-model="scope" :programs="programs" />
          </Section>

          <Button variant="Primary" mode="Block" @click="createInvite">
            Create invite
          </Button>
        </Page>

        <InviteSheet
          v-model:open="sheetOpen"
          group-name="Young Professionals"
          :invite-code="inviteCode"
          :invite-url="inviteUrl"
          :qr-src="qrSrc"
        >
          <template #scope>
            <RoleSelector v-model="role" />
          </template>
        </InviteSheet>
      </div>
    </DeviceFrame>
  </Story>
</template>

<style scoped>
.InviteFlow {
  display: flex;
  flex-direction: column;
  min-height: 100%;
  background: var(--bg-canvas);
}
.InviteFlow__body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: var(--space-lg);
  padding-top: var(--space-md);
  padding-bottom: var(--space-xl);
}
</style>
