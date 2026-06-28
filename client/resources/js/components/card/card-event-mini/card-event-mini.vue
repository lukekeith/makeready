<script lang="ts">
// CardEventMini — compact 120×188 event tile (iOS CardEventMini). Data-driven;
// leads with a date block (big day number + brand-colored month abbreviation)
// over a title and a single metadata row (icon + value).
//
// Props:
//   title      string                            — event title (2-line clamp)
//   day        number                            — day of month (date block)
//   month      string                            — month abbreviation, e.g. "FEB"
//   dataItems  Array<{ icon?: string; value }>   — metadata; only the first is
//                                                   rendered (iOS parity). `icon`
//                                                   is inline SVG markup.
import { cva } from '../../../util/cva'

// Single fixed layout today (date-display tile). CVA kept for parity with the
// other card twins and to leave room for future image styles.
export const CardEventMiniCva = cva('CardEventMini', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import DataComponent from '../../data/data-component/data-component.vue'

export interface CardEventMiniDataItem {
  icon?: string
  value: string
}

interface Props {
  title: string
  day: number
  month: string
  dataItems?: CardEventMiniDataItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  dataItems: () => [],
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() => classnames('CardEventMini', props.class))
const firstItem = computed(() => props.dataItems[0] ?? null)

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
    <div class="CardEventMini__media">
      <span class="CardEventMini__day">{{ day }}</span>
      <span class="CardEventMini__month">{{ month }}</span>
    </div>

    <div class="CardEventMini__body">
      <h3 class="CardEventMini__title">{{ title }}</h3>
      <DataComponent
        v-if="firstItem"
        variant="IconValue"
        :value="firstItem.value"
        class="CardEventMini__meta"
      >
        <template v-if="firstItem.icon" #icon>
          <span v-html="firstItem.icon" />
        </template>
      </DataComponent>
    </div>
  </div>
</template>
