<script setup lang="ts">
// SlideStack — web twin of iPhone Components/Layout/SlideStack.swift.
//
// The canonical in-page horizontal push: two full-width panes in a row, the
// track translating by ±100% over 300ms ease-in-out (Motion.standard).
// Mechanics mirror iOS exactly:
//   • Two-step insertion: the detail pane MOUNTS first (offscreen), then the
//     slide starts on the next frame — so layout completes and content rides
//     the animation instead of popping at its final position.
//   • Completion-tied unmount: the detail stays mounted through the whole
//     slide-out and unmounts on transitionend (never a wall-clock timer).
//   • Re-presentation mid-dismiss re-slides without unmounting; dismissal in
//     the same tick as presentation is guarded.
// The detail slot receives the MOUNTED item, which outlives the binding during
// slide-out, so content never vanishes mid-animation.
import { nextTick, ref, watch } from 'vue'

const props = withDefaults(
  defineProps<{
    /** Navigation state: non-null presents the detail pane, null dismisses. */
    item: unknown | null
    /**
     * Which edge the detail slides in from — iOS SlideStack's `detailEdge`.
     * 'trailing' (default) = detail from the right; 'leading' = detail from the
     * LEFT (GroupHomePage settings). iOS disables edge-swipe-back for leading.
     */
    detailEdge?: 'trailing' | 'leading'
  }>(),
  { detailEdge: 'trailing' },
)

const emit = defineEmits<{ dismissComplete: [] }>()

const mountedItem = ref<unknown | null>(null)
const slid = ref(false)

watch(
  () => props.item,
  (newItem) => {
    if (newItem !== null && newItem !== undefined) {
      if (mountedItem.value === null) {
        // Step 1: mount the detail now (offscreen, invisible).
        mountedItem.value = newItem
        // Step 2: slide on the next frame (guard same-tick dismissal).
        nextTick(() => {
          requestAnimationFrame(() => {
            if (props.item !== null && props.item !== undefined) slid.value = true
          })
        })
      } else {
        // Already mounted: swap content in place; re-slide if a dismissal was
        // in flight.
        mountedItem.value = newItem
        if (!slid.value) slid.value = true
      }
    } else if (slid.value) {
      slid.value = false
      // Unmount happens in onTransitionEnd once the slide-out completes.
    } else {
      // Dismissed before the deferred slide ever started.
      mountedItem.value = null
    }
  },
)

function onTransitionEnd(e: TransitionEvent): void {
  if (e.propertyName !== 'transform' || e.target !== e.currentTarget) return
  if (!slid.value && (props.item === null || props.item === undefined)) {
    mountedItem.value = null
    emit('dismissComplete')
  }
}
</script>

<template>
  <div class="SlideStack">
    <div
      class="SlideStack__track"
      :class="{
        'SlideStack__track--slid': slid,
        'SlideStack__track--leading': detailEdge === 'leading',
      }"
      @transitionend="onTransitionEnd"
    >
      <!-- Leading edge: detail pane sits FIRST in the track (to the left of the
           primary); the resting transform shows the primary, sliding back to 0
           reveals the detail from the left. -->
      <div v-if="detailEdge === 'leading'" class="SlideStack__pane">
        <slot
          v-if="mountedItem !== null && mountedItem !== undefined"
          name="detail"
          :item="mountedItem"
        />
      </div>
      <div class="SlideStack__pane">
        <slot />
      </div>
      <div v-if="detailEdge !== 'leading'" class="SlideStack__pane">
        <slot
          v-if="mountedItem !== null && mountedItem !== undefined"
          name="detail"
          :item="mountedItem"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.SlideStack {
  position: relative;
  width: 100%;
  height: 100%;
  overflow: hidden;
}

/* Two 100%-width panes; the track moves as ONE compositor layer (iOS
   .compositingGroup() before .offset). */
.SlideStack__track {
  display: flex;
  width: 200%;
  height: 100%;
  transform: translateX(0);
  /* Motion.standard = easeInOut 0.3s. */
  transition: transform 300ms ease-in-out;
  will-change: transform;
}

.SlideStack__track--slid {
  transform: translateX(-50%);
}

/* Leading detail: rest shows the SECOND pane (primary), slide returns to 0 so
   the detail enters from the left and the primary exits right — iOS
   SlideStack detailEdge: .leading (rest at -width, slid at 0). */
.SlideStack__track--leading {
  transform: translateX(-50%);
}

.SlideStack__track--leading.SlideStack__track--slid {
  transform: translateX(0);
}

.SlideStack__pane {
  flex: 0 0 50%;
  width: 50%;
  height: 100%;
  overflow: hidden;
}
</style>
