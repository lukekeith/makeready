<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Image from '../../primitive/image/image.vue'
import Badge from '../../primitive/badge/badge.vue'

// CardSearchResult — compact search-result row (iOS search parity): optional
// thumbnail, title + optional subtitle, and a small type tag badge.
//
// No real layout variants → no CVA. Interactive: emits `click`, role=button.
// `type` maps to a Badge tone (not a CVA variant of this card).
//
// Fields (props):
//   title       string   — result title (1 line, semibold)
//   subtitle    string?  — secondary line (e.g. "Genesis 1 · 12 verses")
//   type        string   — tag label, e.g. 'Lesson' | 'Group' | 'Event'
//   thumbUrl    string?  — leading thumbnail image URL
interface Props {
  title: string
  subtitle?: string
  type: string
  thumbUrl?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  subtitle: '',
  thumbUrl: '',
})

const emit = defineEmits<{ click: [MouseEvent] }>()

// Map common result types to badge tones; unknown types fall back to neutral.
const TYPE_TONE: Record<string, 'Primary' | 'Indigo' | 'Success' | 'Default'> = {
  Lesson: 'Primary',
  Group: 'Indigo',
  Event: 'Success',
}
const typeTone = computed(() => TYPE_TONE[props.type] ?? 'Default')

const classes = computed(() => classnames('CardSearchResult', props.class))

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
    <div v-if="thumbUrl" class="CardSearchResult__thumb">
      <Image
        :src="thumbUrl"
        :alt="title"
        fit="Cover"
        ratio="Square"
        :rounded="true"
        class="CardSearchResult__thumb-img"
      />
    </div>

    <div class="CardSearchResult__body">
      <span class="CardSearchResult__title">{{ title }}</span>
      <span v-if="subtitle" class="CardSearchResult__subtitle">{{ subtitle }}</span>
    </div>

    <Badge :tone="typeTone" size="Sm" class="CardSearchResult__type">{{ type }}</Badge>
  </div>
</template>
