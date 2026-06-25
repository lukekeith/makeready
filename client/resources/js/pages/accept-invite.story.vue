<script setup lang="ts">
import '../../css/app.scss'
import { ref } from 'vue'
import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import Page from '../components/layout/page/page.vue'
import Text from '../components/primitive/text/text.vue'
import AcceptInviteCard from '../components/invite/accept-invite-card/accept-invite-card.vue'

// ── Local state ──────────────────────────────────────────────────────────────
// Swaps the card for a small confirmation once accepted/declined. No store.
type Status = 'pending' | 'accepted' | 'declined'
const status = ref<Status>('pending')

function onAccept() {
  status.value = 'accepted'
}
function onDecline() {
  status.value = 'declined'
}
</script>

<template>
  <Story title="Pages/Accept Invite" :layout="{ type: 'single' }">
    <DeviceFrame size="Md">
      <Page class="AcceptInvite" safe-area>
        <div class="AcceptInvite__center">
          <AcceptInviteCard
            v-if="status === 'pending'"
            inviter-name="Sarah Chen"
            scope-label="Day 4 of Romans"
            role="contributor"
            scope-type="lesson"
            expires-at="in 7 days"
            @accept="onAccept"
            @decline="onDecline"
          />

          <div v-else class="AcceptInvite__confirm">
            <Text variant="Title" tone="Primary" as="h2">
              {{ status === 'accepted' ? 'Accepted!' : 'Invite declined' }}
            </Text>
            <Text variant="Body" tone="Secondary">
              {{
                status === 'accepted'
                  ? 'You now have access to Day 4 of Romans.'
                  : 'No problem — you can ask Sarah for a new invite anytime.'
              }}
            </Text>
          </div>
        </div>
      </Page>
    </DeviceFrame>
  </Story>
</template>

<style scoped>
.AcceptInvite {
  min-height: 100%;
  background: var(--bg-canvas);
}
.AcceptInvite__center {
  min-height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: stretch;
  gap: var(--space-md);
}
.AcceptInvite__confirm {
  display: flex;
  flex-direction: column;
  gap: var(--space-sm);
  text-align: center;
  padding: var(--space-xl) var(--space-md);
}
</style>
