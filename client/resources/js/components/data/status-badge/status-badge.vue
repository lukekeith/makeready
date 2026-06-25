<script lang="ts">
// StatusBadge — data. A thin semantic wrapper over the Badge primitive
// (resources/css/components/primitive/badge.scss — no new scss here). It maps a
// lifecycle `status` to a Badge tone + a humanized uppercase label.
//
// status → tone map:
//   pending      → Warning      (awaiting action)
//   unconfirmed  → Warning      (awaiting action)
//   confirmed    → Success
//   active       → Success
//   completed    → Success
//   expired      → Default      (inert / neutral)
//   revoked      → Destructive  (terminated)
import type { BadgeCva } from '../../primitive/badge/badge.vue'

type Status =
  | 'pending'
  | 'unconfirmed'
  | 'confirmed'
  | 'active'
  | 'completed'
  | 'expired'
  | 'revoked'

type Tone = keyof typeof BadgeCva.tone

const STATUS_TONE: Record<Status, Tone> = {
  pending: 'Warning',
  unconfirmed: 'Warning',
  confirmed: 'Success',
  active: 'Success',
  completed: 'Success',
  expired: 'Default',
  revoked: 'Destructive',
}

export type { Status }
export { STATUS_TONE }
</script>

<script setup lang="ts">
import { computed } from 'vue'
import Badge from '../../primitive/badge/badge.vue'

interface Props {
  status: Status
  dot?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  dot: false,
})

const tone = computed(() => STATUS_TONE[props.status])
const label = computed(() => props.status.toUpperCase())
</script>

<template>
  <Badge :tone="tone" :dot="dot" :class="props.class">{{ label }}</Badge>
</template>
