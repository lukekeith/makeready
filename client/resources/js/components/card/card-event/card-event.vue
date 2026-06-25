<script lang="ts">
import { cva } from '../../../util/cva'

// CardEvent — type-specific event card (iOS CardEvent). Data-driven; renders an
// event as either a horizontal Row or a compact Mini tile, leading with a
// calendar-style date block (big day number + month abbreviation).
//
// Fields (props):
//   title      string                            — event title
//   day        number                            — day of month (date block)
//   month      string                            — month abbreviation, e.g. "AUG"
//   coverUrl   string                            — optional background/cover image
//   dataItems  Array<{ icon?: string; value }>   — optional metadata chips (Row)
//   size       'Row' | 'Mini'                     — layout variant
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/card-event.scss exactly.
export const CardEventCva = cva('CardEvent', {
  variants: {
    size: {
      Row: 'CardEvent--size-row',
      Mini: 'CardEvent--size-mini',
    },
  },
  defaultVariants: {
    size: 'Row',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Image from '../../primitive/image/image.vue'
import DataComponent from '../../data/data-component/data-component.vue'

export interface CardEventDataItem {
  icon?: string
  value: string
}

interface Props {
  title: string
  day: number
  month: string
  coverUrl?: string
  dataItems?: CardEventDataItem[]
  size?: keyof typeof CardEventCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  coverUrl: '',
  dataItems: () => [],
  size: () => CardEventCva.defaults?.size as keyof typeof CardEventCva.size,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames(CardEventCva.variants({ size: props.size }), props.class)
)

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
    <div class="CardEvent__date">
      <template v-if="coverUrl">
        <Image
          :src="coverUrl"
          :alt="title"
          fit="Cover"
          ratio="Auto"
          class="CardEvent__date-image"
        />
        <span class="CardEvent__date-scrim" aria-hidden="true" />
      </template>
      <div class="CardEvent__date-inner">
        <span class="CardEvent__day">{{ day }}</span>
        <span class="CardEvent__month">{{ month }}</span>
      </div>
    </div>

    <div class="CardEvent__body">
      <h3 class="CardEvent__title">{{ title }}</h3>
      <div
        v-if="dataItems.length && size === 'Row'"
        class="CardEvent__data DataComponent-row"
      >
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
  </div>
</template>
