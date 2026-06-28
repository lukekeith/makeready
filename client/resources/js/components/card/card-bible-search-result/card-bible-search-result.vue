<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// CardBibleSearchResult — Bible search result card (iOS CardBibleSearchResult).
// Data-driven; renders a reference + verse preview, or — when a `title` is
// present (a named pericope / concept hit) — the title with its reference
// stacked beneath and a summary below.
//
// Fields (props):
//   passage      string  — Bible reference (e.g. "John 3:16")
//   text         string  — verse preview text
//   title        string? — named-passage title (presence switches to Passage layout)
//   description  string? — named-passage summary (falls back to `text`)
//
// Two layouts mirror the SwiftUI component exactly:
//   Verse   (no title): reference (bold) + verse text, no inter-row gap
//   Passage (title)   : title (bold) + reference (50% white) + summary, 2px gaps
//
// Class names mirror the BEM modifiers in
// resources/css/components/card/card-bible-search-result.scss.
interface Props {
  passage: string
  text: string
  title?: string
  description?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  description: '',
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const isPassage = computed(() => props.title.length > 0)

const classes = computed(() =>
  classnames(
    'CardBibleSearchResult',
    isPassage.value
      ? 'CardBibleSearchResult--passage'
      : 'CardBibleSearchResult--verse',
    props.class
  )
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
    <template v-if="isPassage">
      <h3 class="CardBibleSearchResult__title">{{ title }}</h3>
      <p class="CardBibleSearchResult__reference">{{ passage }}</p>
      <p class="CardBibleSearchResult__summary">{{ description || text }}</p>
    </template>
    <template v-else>
      <h3 class="CardBibleSearchResult__passage">{{ passage }}</h3>
      <p class="CardBibleSearchResult__text">{{ text }}</p>
    </template>
  </div>
</template>
