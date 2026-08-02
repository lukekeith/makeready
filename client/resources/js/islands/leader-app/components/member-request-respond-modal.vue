<script setup lang="ts">
// MemberRequestRespondModal host — production presentation of the
// `.memberRequestRespond` topLevel RAW route. iOS RAW chrome provides
// NOTHING, so this host supplies what the iOS modal does itself: the
// synchronized enter/exit animation (ONE timing for wash-opacity and
// content-scale — iOS runs both in a single spring: appear 0.4/0.85,
// dismiss 0.3/0.85) and the dismiss-STRICTLY-before-act sequencing (the
// exit animation completes, the overlay leaves the stack, and only then the
// action callback fires — the network request is never in flight while the
// modal is visible).
import { onMounted, ref } from 'vue'
import MemberRequestRespond from '../../../components/card/member-request-respond/member-request-respond.vue'
import { useOverlayManager } from '../overlay/overlay.store'

interface Props {
  overlayId?: string
  memberName: string
  groupName: string
  dateLabel: string
  timeLabel: string
}

const props = withDefaults(defineProps<Props>(), { overlayId: '' })

// Terminal actions, invoked AFTER the exit animation + overlay removal.
const emit = defineEmits<{ approve: []; reject: []; cancel: [] }>()

const overlayManager = useOverlayManager()
const visible = ref(false)
// iOS has no re-entrancy guard; the web one is free and prevents double-fire.
let dismissing = false

onMounted(() => {
  requestAnimationFrame(() => requestAnimationFrame(() => (visible.value = true)))
  if (props.overlayId) {
    overlayManager.registerAnimatedDismiss(props.overlayId, () => {
      visible.value = false
      // iOS ModalAnimations.dismiss ≈ 300ms.
      setTimeout(() => overlayManager.finalize(props.overlayId), 300)
    })
  }
})

function dismissThen(action?: () => void): void {
  if (dismissing) return
  dismissing = true
  visible.value = false
  setTimeout(() => {
    if (props.overlayId) overlayManager.finalize(props.overlayId)
    action?.()
  }, 300)
}
</script>

<template>
  <div class="RespondModalHost" :class="{ 'RespondModalHost--visible': visible }">
    <MemberRequestRespond
      :member-name="memberName"
      :group-name="groupName"
      :date-label="dateLabel"
      :time-label="timeLabel"
      @approve="dismissThen(() => emit('approve'))"
      @reject="dismissThen(() => emit('reject'))"
      @cancel="dismissThen(() => emit('cancel'))"
    />
  </div>
</template>

<style>
/* iOS: wash opacity + content scale animate in ONE spring — opacity on the
   whole layer, scale on the content only. Spring approx per the foundation
   tokens (present ≈ 400ms cubic-bezier(0.32,0.72,0,1), dismiss 300ms ease-in). */
.RespondModalHost {
  position: fixed;
  inset: 0;
  opacity: 0;
  transition: opacity 0.3s ease-in;
}

.RespondModalHost .MemberRequestRespond__content {
  transform: scale(0.9);
  transition: transform 0.3s ease-in;
}

.RespondModalHost--visible {
  opacity: 1;
  transition: opacity 0.4s cubic-bezier(0.32, 0.72, 0, 1);
}

.RespondModalHost--visible .MemberRequestRespond__content {
  transform: scale(1);
  transition: transform 0.4s cubic-bezier(0.32, 0.72, 0, 1);
}
</style>
