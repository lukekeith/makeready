<script setup lang="ts">
import { classnames } from '../../../util/classnames'

// CardActivity — a single feed item (iOS activity feed parity): a leading icon
// in a translucent circle, the activity text (rich — supply markup via the
// default slot, or plain text via the `text` prop), and a trailing timestamp.
//
// No real layout variants → no CVA. Non-interactive by default (feed line).
//
// Fields (props):
//   text        string   — activity text (used when the default slot is empty)
//   timestamp   string   — pre-formatted relative time (e.g. "2h ago")
//   icon        string?  — raw SVG markup for the leading icon (v-html)
interface Props {
  text?: string
  timestamp: string
  icon?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  text: '',
  icon: '',
})
</script>

<template>
  <div :class="classnames('CardActivity', props.class)">
    <span class="CardActivity__icon" aria-hidden="true">
      <span v-if="icon" v-html="icon" />
      <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="9" />
        <path d="M12 8v4l2.5 2.5" />
      </svg>
    </span>

    <div class="CardActivity__body">
      <p class="CardActivity__text">
        <slot>{{ text }}</slot>
      </p>
      <span class="CardActivity__timestamp">{{ timestamp }}</span>
    </div>
  </div>
</template>
