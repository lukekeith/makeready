<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import BottomSheet from '../../overlay/bottom-sheet/bottom-sheet.vue'
import QRCodeDisplay from '../qr-code-display/qr-code-display.vue'
import CopyLinkField from '../copy-link-field/copy-link-field.vue'
import ShareButton from '../share-button/share-button.vue'

// InviteSheet — invite domain. A bottom sheet for sharing a group/scope invite.
// Composes the BottomSheet overlay (v-model:open) and stacks the invite payload
// inside: a title, the invite code shown large + monospace, the QR panel, a
// copy-link field, and a share button. An optional `#scope` slot above the
// share row lets callers drop in a RoleSelector / ScopeSelector so the invite
// can be scoped before sharing. Presentational only — generating the QR /
// resolving the URL happens upstream; this just lays out what it's given.

interface Props {
  /** Controlled open state (v-model:open). */
  open: boolean
  /** Group (or scope) name the invite targets — shown in the title. */
  groupName: string
  /** Short human invite code, rendered large + monospace. */
  inviteCode: string
  /** Full invite URL — passed to CopyLinkField and ShareButton. */
  inviteUrl: string
  /** Data-URL / image URL of the generated QR (from /api/qrcode/generate). */
  qrSrc?: string
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ 'update:open': [boolean] }>()

const title = computed(() => `Invite to ${props.groupName}`)

const classes = computed(() => classnames('InviteSheet', props.class))

function onOpenChange(next: boolean) {
  emit('update:open', next)
}
</script>

<template>
  <BottomSheet :open="open" :title="title" @update:open="onOpenChange">
    <div :class="classes">
      <p class="InviteSheet__code-label">Invite code</p>
      <p class="InviteSheet__code">{{ inviteCode }}</p>

      <div class="InviteSheet__qr">
        <QRCodeDisplay :src="qrSrc" size="Md" />
      </div>

      <CopyLinkField class="InviteSheet__link" :url="inviteUrl" label="Invite link" />

      <div v-if="$slots.scope" class="InviteSheet__scope">
        <slot name="scope" />
      </div>

      <div class="InviteSheet__share">
        <ShareButton :url="inviteUrl" :title="title" />
      </div>
    </div>
  </BottomSheet>
</template>
