<script lang="ts">
import { cva } from '../../../util/cva'

// ListItem — layout. A single list row with optional leading / trailing slots
// and a title/subtitle main content. CVA modifiers mirror the SCSS modifiers in
// resources/css/components/layout/list-item.scss exactly. Styles are global via
// app.scss, so this component only emits classes.
export const ListItemCva = cva('ListItem', {
  variants: {
    state: {
      Default: '',
      Interactive: 'ListItem--interactive',
      Disabled: 'ListItem--disabled',
    },
  },
  defaultVariants: {
    state: 'Default',
  },
})
</script>

<script setup lang="ts">
import { computed, useSlots } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  title?: string
  subtitle?: string
  interactive?: boolean
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  interactive: false,
  disabled: false,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const slots = useSlots()

const state = computed<keyof typeof ListItemCva.state>(() => {
  if (props.disabled) return 'Disabled'
  if (props.interactive) return 'Interactive'
  return 'Default'
})

const classes = computed(() =>
  classnames(ListItemCva.variants({ state: state.value }), props.class)
)

const hasDefaultSlot = computed(() => Boolean(slots.default))

const onClick = (e: MouseEvent) => {
  if (!props.interactive || props.disabled) return
  emit('click', e)
}
</script>

<template>
  <div
    :class="classes"
    :role="interactive ? 'button' : undefined"
    :tabindex="interactive && !disabled ? 0 : undefined"
    :aria-disabled="disabled || undefined"
    @click="onClick"
  >
    <div v-if="$slots.leading" class="ListItem__leading">
      <slot name="leading" />
    </div>

    <div class="ListItem__content">
      <slot v-if="hasDefaultSlot" />
      <template v-else>
        <span v-if="title" class="ListItem__title">{{ title }}</span>
        <span v-if="subtitle" class="ListItem__subtitle">{{ subtitle }}</span>
      </template>
    </div>

    <div v-if="$slots.trailing" class="ListItem__trailing">
      <slot name="trailing" />
    </div>
  </div>
</template>
