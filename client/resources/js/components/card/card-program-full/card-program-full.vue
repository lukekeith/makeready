<script lang="ts">
import { cva } from '../../../util/cva'

// CardProgramFull — full-width program browse card (iOS CardProgramFull). A
// 280px-tall card: a full-bleed cover image (or a faint placeholder + a centered
// book glyph) with a bottom content overlay (semi-transparent cardBackground)
// carrying the title, description, tags, a DataComponent metadata row, and an
// author/date footer. A green "Published" capsule sits top-right when published.
//
// Fields (props):
//   title         string                            — program title (1 line, ellipsis)
//   description   string                            — short blurb (2-line clamp)
//   tags          string[]                          — capsule tags (white 15% pills)
//   dataItems     Array<{ icon?: string; value }>   — metadata chips (icon = inline SVG)
//   authorName    string                            — footer author (white 50%)
//   relativeDate  string                            — footer relative date (white 30%)
//   published     boolean                           — show the green "Published" capsule
//   coverUrl      string                            — optional cover image; falls back
//                                                      to the faint placeholder + glyph
//
// There is a single visual variant — the compare variant changes only the data,
// not the layout.
export const CardProgramFullCva = cva('CardProgramFull', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
import { classnames } from '../../../util/classnames'
import DataComponent from '../../data/data-component/data-component.vue'

export interface CardProgramFullDataItem {
  icon?: string
  value: string
}

interface Props {
  title: string
  description?: string
  tags?: string[]
  dataItems?: CardProgramFullDataItem[]
  authorName?: string
  relativeDate?: string
  published?: boolean
  coverUrl?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  description: '',
  tags: () => [],
  dataItems: () => [],
  authorName: '',
  relativeDate: '',
  published: false,
  coverUrl: '',
})

const emit = defineEmits<{ click: [MouseEvent] }>()
const onClick = (e: MouseEvent) => emit('click', e)
</script>

<template>
  <div :class="classnames('CardProgramFull', props.class)" @click="onClick">
    <div class="CardProgramFull__cover">
      <img
        v-if="coverUrl"
        :src="coverUrl"
        :alt="title"
        class="CardProgramFull__image"
      />
      <div v-else class="CardProgramFull__placeholder" aria-hidden="true">
        <span class="CardProgramFull__placeholderIcon">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 6.5C10.5 5.3 8.4 4.6 6 4.6c-1 0-2 .1-3 .4v13.4c1-.3 2-.4 3-.4 2.4 0 4.5.7 6 1.9 1.5-1.2 3.6-1.9 6-1.9 1 0 2 .1 3 .4V5c-1-.3-2-.4-3-.4-2.4 0-4.5.7-6 1.9z"/>
          </svg>
        </span>
      </div>
    </div>

    <div v-if="published" class="CardProgramFull__badge">Published</div>

    <div class="CardProgramFull__overlay">
      <div class="CardProgramFull__head">
        <h3 class="CardProgramFull__title">{{ title }}</h3>
        <p v-if="description" class="CardProgramFull__description">{{ description }}</p>
      </div>

      <div v-if="tags.length" class="CardProgramFull__tags">
        <span v-for="(tag, i) in tags" :key="i" class="CardProgramFull__tag">{{ tag }}</span>
      </div>

      <div v-if="dataItems.length" class="CardProgramFull__data DataComponent-row">
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

      <div class="CardProgramFull__meta">
        <span v-if="authorName" class="CardProgramFull__author">{{ authorName }}</span>
        <span v-if="relativeDate" class="CardProgramFull__date">{{ relativeDate }}</span>
      </div>
    </div>
  </div>
</template>
