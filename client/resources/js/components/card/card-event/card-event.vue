<script lang="ts">
// CardEvent — full-width event row (iOS CardEvent). Data-driven; title +
// subtitle + a single metadata row on the left, a date or time block on the
// right.
//
// Props:
//   title      string                            — event title (1 line)
//   subtitle   string?                           — secondary line (1 line)
//   day        number?                           — date block: day of month
//   month      string?                           — date block: month abbr (e.g. "OCT")
//   time       string?                           — time block: time (e.g. "6:30")
//   period     string?                           — time block: AM/PM
//   dataItems  Array<{ icon?: string; value }>   — metadata; `icon` is inline SVG
//
// The right block renders a time display when `time`/`period` are given,
// otherwise a date display from `day`/`month`.
import { cva } from '../../../util/cva'

// Single fixed layout today. CVA kept for parity with the other card twins.
export const CardEventCva = cva('CardEvent', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import DataComponent from '../../data/data-component/data-component.vue'

export interface CardEventDataItem {
  icon?: string
  value: string
}

interface Props {
  title: string
  subtitle?: string
  day?: number
  month?: string
  time?: string
  period?: string
  dataItems?: CardEventDataItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  dataItems: () => [],
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const isTime = computed(() => props.time != null && props.time !== '')
const classes = computed(() => classnames('CardEvent', props.class))
const blockClasses = computed(() => [
  'CardEvent__block',
  isTime.value ? 'CardEvent__block--time' : 'CardEvent__block--date',
])

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
    <div class="CardEvent__body">
      <h3 class="CardEvent__title">{{ title }}</h3>
      <p v-if="subtitle" class="CardEvent__subtitle">{{ subtitle }}</p>
      <div v-if="dataItems.length" class="CardEvent__meta DataComponent-row">
        <DataComponent
          v-for="(item, i) in dataItems"
          :key="i"
          variant="IconValue"
          :value="item.value"
        >
          <template v-if="item.icon" #icon>
            <span v-html="item.icon" />
          </template>
        </DataComponent>
      </div>
    </div>

    <div :class="blockClasses">
      <template v-if="isTime">
        <span class="CardEvent__primary">{{ time }}</span>
        <span class="CardEvent__secondary">{{ period }}</span>
      </template>
      <template v-else>
        <span class="CardEvent__primary">{{ day }}</span>
        <span class="CardEvent__secondary">{{ month }}</span>
      </template>
    </div>
  </div>
</template>
