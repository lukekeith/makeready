<script lang="ts">
// Section — layout. A titled content section: an overline-style head (title +
// optional right-aligned text action) over a body slot, stacked with a
// consistent vertical gap. Styles are global via app.scss, so this component
// only emits classes.
//
// No CVA variant table: Section has no enum variants — title/action are content
// props, not style modifiers.
</script>

<script setup lang="ts">
import { classnames } from '../../../util/classnames'

interface Props {
  /** Overline-style section title. */
  title?: string
  /** Optional right-aligned text action; renders a button that emits `action`. */
  actionLabel?: string
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ action: [] }>()
</script>

<template>
  <section :class="classnames('Section', props.class)">
    <div v-if="title || actionLabel" class="Section__head">
      <span v-if="title" class="Section__title">{{ title }}</span>
      <button
        v-if="actionLabel"
        type="button"
        class="Section__action"
        @click="emit('action')"
      >
        {{ actionLabel }}
      </button>
    </div>
    <div class="Section__body">
      <slot />
    </div>
  </section>
</template>
