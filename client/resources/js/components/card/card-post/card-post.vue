<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Avatar from '../../primitive/avatar/avatar.vue'
import Image from '../../primitive/image/image.vue'

// CardPost — an announcement / post card (iOS post parity). Header is an avatar
// + author name + timestamp; below is the post body, and an optional rounded
// media image.
//
// No real layout variants → no CVA. Interactive: emits `click`, role=button.
//
// Fields (props):
//   author             string   — post author name (semibold)
//   authorAvatarUrl    string?  — author avatar image URL
//   timestamp          string   — pre-formatted relative time (e.g. "2h ago")
//   body               string   — post body text
//   mediaUrl           string?  — attached image URL (rendered rounded when present)
interface Props {
  author: string
  authorAvatarUrl?: string
  timestamp: string
  body: string
  mediaUrl?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  authorAvatarUrl: '',
  mediaUrl: '',
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() => classnames('CardPost', props.class))

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
    <header class="CardPost__header">
      <Avatar
        size="Sm"
        :src="authorAvatarUrl || undefined"
        :alt="author"
        class="CardPost__avatar"
      />
      <div class="CardPost__byline">
        <span class="CardPost__author">{{ author }}</span>
        <span class="CardPost__timestamp">{{ timestamp }}</span>
      </div>
    </header>

    <p class="CardPost__body">{{ body }}</p>

    <Image
      v-if="mediaUrl"
      :src="mediaUrl"
      :alt="''"
      fit="Cover"
      ratio="ThreeTwo"
      :rounded="true"
      class="CardPost__media"
    />
  </div>
</template>
