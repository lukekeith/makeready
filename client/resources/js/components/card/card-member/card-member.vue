<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Avatar from '../../primitive/avatar/avatar.vue'
import Badge from '../../primitive/badge/badge.vue'

// CardMember — list row for a single member (iOS member row parity). Avatar +
// name, with optional role/meta subtext and a trailing slot for an action. When
// `pending` is set the row shows a "PENDING" Warning badge.
//
// No real layout variants → no CVA. Interactive: emits `click`, role=button.
//
// Fields (props):
//   name        string   — member display name (1 line, semibold)
//   role        string?  — role label shown in the subtext row (e.g. "Group Leader")
//   meta        string?  — extra subtext (e.g. "Joined Apr 2") — joined to role with a dot
//   avatarUrl   string?  — avatar image URL
//   initials    string?  — avatar fallback initials when no image
//   pending     boolean  — show "PENDING" Warning badge after the name
interface Props {
  name: string
  role?: string
  meta?: string
  avatarUrl?: string
  initials?: string
  pending?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  role: '',
  meta: '',
  avatarUrl: '',
  initials: '',
  pending: false,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const subtext = computed(() =>
  [props.role, props.meta].filter(Boolean).join(' · ')
)

const classes = computed(() =>
  classnames('CardMember', props.pending && 'CardMember--is-pending', props.class)
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
    <Avatar
      size="Md"
      :src="avatarUrl || undefined"
      :initials="initials"
      :alt="name"
      class="CardMember__avatar"
    />

    <div class="CardMember__body">
      <div class="CardMember__heading">
        <span class="CardMember__name">{{ name }}</span>
        <Badge v-if="pending" tone="Warning" size="Sm" class="CardMember__badge">
          PENDING
        </Badge>
      </div>
      <p v-if="subtext" class="CardMember__meta">{{ subtext }}</p>
    </div>

    <div v-if="$slots.trailing" class="CardMember__trailing">
      <slot name="trailing" />
    </div>
  </div>
</template>
