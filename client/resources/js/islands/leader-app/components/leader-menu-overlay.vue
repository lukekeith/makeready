<script setup lang="ts">
// LeaderMenuOverlay — web equivalent of the iPhone ManagedMenuView chrome:
// a dark scrim over the app with a slide-up sheet pinned to the bottom of the
// phone column. Tap-scrim (or Escape) dismisses, matching iOS tap-outside.
import { onBeforeUnmount, onMounted } from 'vue'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ close: [] }>()

function onKeydown(e: KeyboardEvent): void {
  if (e.key === 'Escape' && props.open) emit('close')
}
onMounted(() => document.addEventListener('keydown', onKeydown))
onBeforeUnmount(() => document.removeEventListener('keydown', onKeydown))
</script>

<template>
  <Teleport to="body">
    <Transition name="LeaderMenuOverlay">
      <div v-if="open" class="LeaderMenuOverlay" @click.self="emit('close')">
        <div class="LeaderMenuOverlay__sheet">
          <slot />
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* Covers the viewport but clips the sheet to the 480px phone column. */
.LeaderMenuOverlay {
  position: fixed;
  inset: 0;
  z-index: 40;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  background: rgba(0, 0, 0, 0.5);
}

.LeaderMenuOverlay__sheet {
  width: 100%;
  max-width: 480px;
  background: var(--color-canvas);
  border-radius: 16px 16px 0 0;
  overflow: hidden;
  transition: transform 0.3s ease;
}

.LeaderMenuOverlay-enter-active,
.LeaderMenuOverlay-leave-active {
  transition: background-color 0.3s ease;
}

.LeaderMenuOverlay-enter-from,
.LeaderMenuOverlay-leave-to {
  background: rgba(0, 0, 0, 0);
}

.LeaderMenuOverlay-enter-from .LeaderMenuOverlay__sheet,
.LeaderMenuOverlay-leave-to .LeaderMenuOverlay__sheet {
  transform: translateY(100%);
}
</style>
