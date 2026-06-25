<script setup lang="ts">
// Capture-only island: renders a single design-system component by name with
// arbitrary props, so the Compare tool can screenshot it in isolation against
// the same data the iPhone app uses. Add components to the registry below as
// new component comparisons are introduced.
import { computed } from 'vue'
import CardStudy from '../../card/card-study/card-study.vue'
import CardGroup from '../../card/card-group/card-group.vue'

const props = defineProps<{
  component: string
  props?: Record<string, unknown>
}>()

const registry: Record<string, unknown> = {
  CardStudy,
  CardGroup,
}

const Resolved = computed(() => registry[props.component] ?? null)
</script>

<template>
  <component :is="Resolved" v-if="Resolved" v-bind="props.props" />
  <div v-else style="color: #f87171; font-family: monospace; padding: 16px">
    Unknown capture component: "{{ component }}"
  </div>
</template>
