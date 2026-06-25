<script lang="ts">
// SlideStack — navigation. Hand-rolled push/pop slide navigation (iOS SlideStack
// parity). Manages a stack of view keys; pushing slides the new view in from the
// right while the previous one shifts slightly left; popping reverses. The view
// for each key is rendered through the #default="{ key }" scoped slot.
//
// Two ways to drive it:
//   • v-model — bind an array of view keys; mutate it (push/pop) externally.
//   • imperative — call the exposed push(key) / pop() methods via a ref.
//
// No CVA variants. CSS lives in
// resources/css/components/navigation/slide-stack.scss (global via app.scss).
</script>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'

interface Props {
  // The stack of view keys (bottom → top). Optional: when omitted the component
  // manages its own internal stack via the exposed push/pop API.
  modelValue?: string[]
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ 'update:modelValue': [string[]] }>()

// Internal stack mirrors modelValue when provided, else is self-managed.
const internal = ref<string[]>(props.modelValue ? [...props.modelValue] : [])

watch(
  () => props.modelValue,
  (next) => {
    if (next && next !== internal.value) syncTo([...next])
  }
)

const stack = computed(() => internal.value)
const topKey = computed(() => stack.value[stack.value.length - 1])

// Transition bookkeeping: when a slide is in flight we render both the previous
// (outgoing) and current (incoming) panels and apply the push/pop modifiers.
type Direction = 'push' | 'pop' | null
const direction = ref<Direction>(null)
const outgoingKey = ref<string | undefined>(undefined)
const animating = ref(false)

const commit = (next: string[]) => {
  internal.value = next
  emit('update:modelValue', next)
}

// Replace the whole stack (used when v-model changes externally). We infer the
// direction from the length delta for a sensible animation.
const syncTo = (next: string[]) => {
  const prevTop = topKey.value
  if (next.length > internal.value.length) startTransition('push', prevTop)
  else if (next.length < internal.value.length) startTransition('pop', prevTop)
  internal.value = next
}

const prefersReducedMotion = () =>
  typeof window !== 'undefined' &&
  typeof window.matchMedia === 'function' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

const startTransition = (dir: Direction, fromKey: string | undefined) => {
  // With reduced motion the keyframes are disabled, so animationend never
  // fires — skip the animating phase entirely and let the new view snap in.
  if (prefersReducedMotion()) {
    endTransition()
    return
  }
  outgoingKey.value = fromKey
  direction.value = dir
  animating.value = true
}

const endTransition = () => {
  animating.value = false
  direction.value = null
  outgoingKey.value = undefined
}

const push = (key: string) => {
  if (key === topKey.value) return
  startTransition('push', topKey.value)
  commit([...internal.value, key])
}

const pop = () => {
  if (internal.value.length <= 1) return
  startTransition('pop', topKey.value)
  commit(internal.value.slice(0, -1))
}

defineExpose({ push, pop })
</script>

<template>
  <div :class="['SlideStack', props.class]">
    <!-- Outgoing panel (previous top) — only during a transition. -->
    <div
      v-if="animating && outgoingKey !== undefined && outgoingKey !== topKey"
      :key="`out-${outgoingKey}`"
      class="SlideStack__panel"
      :class="[
        direction === 'push' && 'SlideStack__panel--exit-push',
        direction === 'pop' && 'SlideStack__panel--exit-pop',
      ]"
    >
      <slot :key="outgoingKey" />
    </div>

    <!-- Incoming / current panel (top of stack). -->
    <div
      v-if="topKey !== undefined"
      :key="`in-${topKey}`"
      class="SlideStack__panel"
      :class="[
        animating && direction === 'push' && 'SlideStack__panel--enter-push',
        animating && direction === 'pop' && 'SlideStack__panel--enter-pop',
      ]"
      @transitionend="endTransition"
      @animationend="endTransition"
    >
      <slot :key="topKey" />
    </div>
  </div>
</template>
