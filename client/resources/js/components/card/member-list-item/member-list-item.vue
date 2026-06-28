<script lang="ts">
import { cva } from '../../../util/cva'

// MemberListItem — twin of iOS Components/Display/MemberListItem.swift. A full-
// width member/contact list row: circular initials avatar, name, optional
// demographics (Age / Joined) + group chips, and an optional trailing Invite
// pill. Four variants drive what renders:
//
//   contact               name + Invite, no demographics / groups
//   member                name + demographics + group(s), NO Invite
//   memberWithInvite      name + demographics + group(s) + Invite
//   memberMultipleGroups  name + demographics + up to 2 groups + Invite
//
// The avatar uses iOS Color.gray.opacity(0.3) (NOT the brand-gradient Avatar
// component) with white bold initials. Demographics + group chips are 11pt with
// 0.1px tracking. The Invite pill reuses the ActionButton twin (purple).
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/member-list-item.scss exactly.
export const MemberListItemCva = cva('MemberListItem', {
  variants: {
    variant: {
      contact: 'MemberListItem--contact',
      member: 'MemberListItem--member',
      memberWithInvite: 'MemberListItem--member-with-invite',
      memberMultipleGroups: 'MemberListItem--member-multiple-groups',
    },
  },
  defaultVariants: {
    variant: 'memberWithInvite',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import ActionButton from '../action-button/action-button.vue'

interface Props {
  variant?: keyof typeof MemberListItemCva.variant
  firstName?: string
  lastName?: string
  age?: number | null
  // Pre-formatted join date label (e.g. "Dec 31, 2024"); the adapter formats it
  // in LOCAL tz to match the iPhone DateFormatter (UTC midnight shifts a day).
  joinDateLabel?: string
  groups?: string[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: () =>
    MemberListItemCva.defaults?.variant as keyof typeof MemberListItemCva.variant,
  firstName: '',
  lastName: '',
  age: null,
  joinDateLabel: '',
  groups: () => [],
})

// iOS getInitials: first char of first + first char of last, uppercased.
const initials = computed(() => {
  const first = props.firstName?.charAt(0).toUpperCase() ?? ''
  const last = props.lastName?.charAt(0).toUpperCase() ?? ''
  if (first && last) return first + last
  if (first) return first
  return '?'
})

const fullName = computed(() =>
  `${props.firstName ?? ''} ${props.lastName ?? ''}`.trim() || 'Unknown'
)

// Demographics + group chips render for every variant except `contact`.
const showDetails = computed(() => props.variant !== 'contact')

// Invite pill shows for contact / memberWithInvite / memberMultipleGroups.
const showInvite = computed(() => props.variant !== 'member')

// iOS ForEach(member.groups.prefix(2)) — at most two chips.
const visibleGroups = computed(() => (props.groups ?? []).slice(0, 2))

const classes = computed(() =>
  classnames(MemberListItemCva.variants({ variant: props.variant }), props.class)
)
</script>

<template>
  <div :class="classes">
    <!-- Avatar: gray@0.3 circle with white bold initials -->
    <div class="MemberListItem__avatar" role="img" :aria-label="fullName">
      <span class="MemberListItem__initials">{{ initials }}</span>
    </div>

    <!-- Details -->
    <div class="MemberListItem__details">
      <h3 class="MemberListItem__name">{{ fullName }}</h3>

      <template v-if="showDetails">
        <div class="MemberListItem__demographics">
          <span v-if="age != null" class="MemberListItem__stat">
            <span class="MemberListItem__stat-label">Age</span>
            <span class="MemberListItem__stat-value">{{ age }}</span>
          </span>
          <span v-if="joinDateLabel" class="MemberListItem__stat">
            <span class="MemberListItem__stat-label">Joined</span>
            <span class="MemberListItem__stat-value">{{ joinDateLabel }}</span>
          </span>
        </div>

        <div v-if="visibleGroups.length" class="MemberListItem__groups">
          <span
            v-for="(group, i) in visibleGroups"
            :key="i"
            class="MemberListItem__group"
          >{{ group }}</span>
        </div>
      </template>
    </div>

    <!-- Trailing Invite pill -->
    <ActionButton
      v-if="showInvite"
      label="Invite"
      variant="purple"
      class="MemberListItem__invite"
    />
  </div>
</template>
