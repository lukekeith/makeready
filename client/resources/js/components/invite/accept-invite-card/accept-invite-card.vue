<script setup lang="ts">
import { computed } from 'vue'
import Avatar from '../../primitive/avatar/avatar.vue'
import Button from '../../primitive/button/button.vue'
import ScopeBadge from '../scope-badge/scope-badge.vue'

// AcceptInviteCard — invite domain. The accept-invite landing card (NEW to both
// apps). Data-driven against the invite scope descriptor; no store access.
//
// Layout (centered card on --bg-surface / --radius-lg):
//   - inviter row: Avatar + "{inviterName} invited you"
//   - ScopeBadge showing role + scope
//   - the scope label, prominently
//   - optional expiry note (--text-xs / --fg-tertiary)
//   - footer of two Buttons: Accept (Primary) + Decline (Ghost)
//
// Emits `accept` and `decline`.

type Role = 'member' | 'contributor'
type ScopeType = 'program' | 'lesson'

interface Props {
  inviterName: string
  inviterAvatarUrl?: string
  scopeLabel: string
  role: Role
  // Inferred from the scope label / descriptor; defaults to program. The
  // ScopeBadge already shows the human label verbatim, so scopeType only drives
  // the fallback humanization inside the badge.
  scopeType?: ScopeType
  expiresAt?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  scopeType: 'program',
})

const emit = defineEmits<{ accept: []; decline: [] }>()

const inviterInitials = computed(() =>
  props.inviterName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('')
)

const expiryNote = computed(() => {
  if (!props.expiresAt) return null
  return `Expires ${props.expiresAt}`
})
</script>

<template>
  <div :class="['AcceptInviteCard', props.class]">
    <div class="AcceptInviteCard__inviter">
      <Avatar
        class="AcceptInviteCard__avatar"
        size="Lg"
        :src="inviterAvatarUrl"
        :initials="inviterInitials"
        :alt="inviterName"
      />
      <p class="AcceptInviteCard__inviterText">
        <strong class="AcceptInviteCard__inviterName">{{ inviterName }}</strong>
        invited you
      </p>
    </div>

    <ScopeBadge
      class="AcceptInviteCard__badge"
      :role="role"
      :scope-type="scopeType"
    />

    <p class="AcceptInviteCard__scopeLabel">{{ scopeLabel }}</p>

    <p v-if="expiryNote" class="AcceptInviteCard__expiry">{{ expiryNote }}</p>

    <div class="AcceptInviteCard__footer">
      <Button
        class="AcceptInviteCard__action"
        variant="Primary"
        @click="emit('accept')"
      >
        Accept
      </Button>
      <Button
        class="AcceptInviteCard__action"
        variant="Ghost"
        @click="emit('decline')"
      >
        Decline
      </Button>
    </div>
  </div>
</template>
