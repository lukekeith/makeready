<script setup lang="ts">
// SectionedList — layout. Renders a list grouped into titled sections, each with
// a sticky header followed by its rows (emitted via the #item scoped slot).
// No variants → no CVA. Styles are global via app.scss
// (resources/css/components/layout/sectioned-list.scss); this component only
// emits classes.
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Section {
  key: string
  title: string
  items: any[]
}

interface Props {
  sections: Section[]
  class?: string
}

const props = defineProps<Props>()

const classes = computed(() => classnames('SectionedList', props.class))
</script>

<template>
  <div :class="classes">
    <section
      v-for="section in sections"
      :key="section.key"
      class="SectionedList__section"
    >
      <header class="SectionedList__header">{{ section.title }}</header>
      <div class="SectionedList__items" role="list">
        <slot
          v-for="(item, index) in section.items"
          :key="index"
          name="item"
          :item="item"
          :section="section"
        />
      </div>
    </section>
  </div>
</template>
