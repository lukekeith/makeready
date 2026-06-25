<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Badge from '../../primitive/badge/badge.vue'

// CardEnrollment — list card for a member's enrollment in a study program (iOS
// enrollment row parity). Shows the program title, a status badge, an optional
// schedule line, and an optional thin progress bar.
//
// No real layout variants → no CVA. Interactive: emits `click`, role=button.
// `status` maps to a Badge tone (not a CVA variant of this card).
//
// Fields (props):
//   programTitle  string   — study program title (1 line, semibold)
//   status        string   — 'active' | 'pending' | 'completed' (others fall back to neutral)
//   schedule      string?  — schedule blurb (e.g. "Mon & Wed · 7:00 PM")
//   progress      number?  — completion 0–100; renders a thin progress bar when set
type EnrollmentStatus = 'active' | 'pending' | 'completed' | string

interface Props {
  programTitle: string
  status: EnrollmentStatus
  schedule?: string
  progress?: number
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  schedule: '',
  progress: undefined,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const STATUS_TONE: Record<string, 'Success' | 'Warning' | 'Default' | 'Secondary'> = {
  active: 'Success',
  pending: 'Warning',
  completed: 'Secondary',
}
const statusTone = computed(() => STATUS_TONE[props.status] ?? 'Default')
const statusLabel = computed(() =>
  props.status ? props.status.charAt(0).toUpperCase() + props.status.slice(1) : ''
)

const hasProgress = computed(() => typeof props.progress === 'number')
const clampedProgress = computed(() =>
  Math.max(0, Math.min(100, props.progress ?? 0))
)

const classes = computed(() => classnames('CardEnrollment', props.class))

const onClick = (e: MouseEvent) => emit('click', e)
const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault()
    emit('click', e as unknown as MouseEvent)
  }
}
</script>

<template>
  <div
    :class="classes"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <div class="CardEnrollment__heading">
      <h3 class="CardEnrollment__title">{{ programTitle }}</h3>
      <Badge :tone="statusTone" size="Sm" class="CardEnrollment__status">
        {{ statusLabel }}
      </Badge>
    </div>

    <p v-if="schedule" class="CardEnrollment__schedule">{{ schedule }}</p>

    <div
      v-if="hasProgress"
      class="CardEnrollment__progress"
      role="progressbar"
      :aria-valuenow="clampedProgress"
      aria-valuemin="0"
      aria-valuemax="100"
    >
      <div class="CardEnrollment__progress-fill" :style="{ width: `${clampedProgress}%` }" />
    </div>
  </div>
</template>
