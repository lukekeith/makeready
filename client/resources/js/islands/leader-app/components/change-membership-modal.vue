<script setup lang="ts">
// ChangeMembershipModal host — production presentation of the
// `.changeMembership` topLevel RAW route. Same contract as the respond host:
// synchronized wash-opacity + content-scale enter/exit, dismiss-STRICTLY-
// before-act (iOS runs the exit spring to completion, removes the overlay,
// THEN starts the network Task). Panel choreography lives in the twin.
import { onMounted, ref } from 'vue'
import ChangeMembership, {
  type ChangeMembershipMode,
  type TransferCandidate,
} from '../../../components/card/change-membership/change-membership.vue'
import { useOverlayManager } from '../overlay/overlay.store'

interface Props {
  overlayId?: string
  memberName: string
  groupName: string
  mode: ChangeMembershipMode
  candidates: TransferCandidate[]
}

const props = withDefaults(defineProps<Props>(), { overlayId: '' })

const emit = defineEmits<{ remove: []; rejoin: []; transfer: [string]; cancel: [] }>()

const overlayManager = useOverlayManager()
const visible = ref(false)
let dismissing = false

onMounted(() => {
  requestAnimationFrame(() => requestAnimationFrame(() => (visible.value = true)))
  if (props.overlayId) {
    overlayManager.registerAnimatedDismiss(props.overlayId, () => {
      visible.value = false
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
  <div class="ChangeMembershipHost" :class="{ 'ChangeMembershipHost--visible': visible }">
    <ChangeMembership
      :member-name="memberName"
      :group-name="groupName"
      :mode="mode"
      :candidates="candidates"
      @remove="dismissThen(() => emit('remove'))"
      @rejoin="dismissThen(() => emit('rejoin'))"
      @transfer="(id) => dismissThen(() => emit('transfer', id))"
      @close="dismissThen(() => emit('cancel'))"
    />
  </div>
</template>

<style>
.ChangeMembershipHost {
  position: fixed;
  inset: 0;
  opacity: 0;
  transition: opacity 0.3s ease-in;
}

/* Scale the panel content, not the wash (iOS scales the panel ZStack). */
.ChangeMembershipHost .ChangeMembership__panel,
.ChangeMembershipHost .ChangeMembership__close {
  transition: transform 0.3s ease-in;
}

.ChangeMembershipHost:not(.ChangeMembershipHost--visible) .ChangeMembership__panel {
  transform: scale(0.9);
}

.ChangeMembershipHost--visible {
  opacity: 1;
  transition: opacity 0.4s cubic-bezier(0.32, 0.72, 0, 1);
}
</style>
