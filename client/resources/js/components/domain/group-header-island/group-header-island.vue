<script setup lang="ts">
import { ref } from 'vue'
import Modal from '../../primitive/modal/modal.vue'

// Styles live in resources/css/pages/group-home.scss (page-level SCSS is
// authoritative for the group-home screen, and keeping them there means the
// server-rendered header fallback + this island share one stylesheet with no
// unstyled flash before Vue mounts).

interface SwitcherGroup {
  id: string
  name: string
  memberCount: number
  isPrivate: boolean
  coverImageUrl?: string | null
  href: string
  isCurrent: boolean
}

interface CurrentGroup {
  name: string
  orgName?: string | null
  memberCount: number
  isPrivate: boolean
}

interface Props {
  current: CurrentGroup
  groups: SwitcherGroup[]
}

const props = withDefaults(defineProps<Props>(), {
  groups: () => [],
})

// Switching is only meaningful with more than one group; with a single group
// the header renders as a static (non-interactive) hero without the switch pill.
const canSwitch = props.groups.length > 1

const isOpen = ref(false)
const open = () => { if (canSwitch) isOpen.value = true }
const close = () => { isOpen.value = false }

function initial(name: string): string {
  return (name || '?').trim().charAt(0).toUpperCase()
}
</script>

<template>
  <component
    :is="canSwitch ? 'button' : 'div'"
    :type="canSwitch ? 'button' : undefined"
    class="GroupHeader"
    :class="{ 'GroupHeader--static': !canSwitch }"
    :aria-haspopup="canSwitch ? 'dialog' : undefined"
    @click="open"
  >
    <span v-if="canSwitch" class="GroupHeader__switch">
      Switch group
      <svg
        class="GroupHeader__switch-icon"
        width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true"
      >
        <path d="M3 8H13M13 8L9 4M13 8L9 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </span>

    <span class="GroupHeader__info">
      <span class="GroupHeader__heading">
        <span class="GroupHeader__name">{{ current.name }}</span>
        <span v-if="current.orgName" class="GroupHeader__org">{{ current.orgName }}</span>
      </span>

      <span class="GroupHeader__meta">
        <span class="GroupHeader__privacy">
          <svg width="16" height="16" viewBox="0 0 20 20" fill="none" aria-hidden="true">
            <rect x="4.5" y="9" width="11" height="7.5" rx="1.5" stroke="currentColor" stroke-width="1.5" />
            <path
              v-if="current.isPrivate"
              d="M6.75 9V6.5C6.75 4.70507 8.20507 3.25 10 3.25C11.7949 3.25 13.25 4.70507 13.25 6.5V9"
              stroke="currentColor" stroke-width="1.5" stroke-linecap="round"
            />
            <path
              v-else
              d="M6.75 9V6.5C6.75 4.70507 8.20507 3.25 10 3.25C11.4476 3.25 12.674 4.19668 13.0944 5.5"
              stroke="currentColor" stroke-width="1.5" stroke-linecap="round"
            />
          </svg>
          {{ current.isPrivate ? 'Private group' : 'Public group' }}
        </span>
        <span class="GroupHeader__count">
          <span class="GroupHeader__count-value">{{ current.memberCount }}</span>
          <span class="GroupHeader__count-label">{{ current.memberCount === 1 ? 'member' : 'members' }}</span>
        </span>
      </span>
    </span>
  </component>

  <Modal
    v-if="canSwitch"
    :is-open="isOpen"
    mode="Menu"
    aria-title="Switch group"
    aria-description="Choose a group to view"
    @close="close"
  >
    <div class="GroupHeader__menu">
      <p class="GroupHeader__menu-title">Your groups</p>
      <div class="GroupHeader__list">
        <a
          v-for="g in groups"
          :key="g.id"
          class="GroupHeader__card"
          :class="{ 'GroupHeader__card--current': g.isCurrent }"
          :href="g.href"
          :aria-current="g.isCurrent ? 'true' : undefined"
        >
          <span class="GroupHeader__card-cover">
            <img v-if="g.coverImageUrl" :src="g.coverImageUrl" alt="" />
            <span v-else class="GroupHeader__card-initial">{{ initial(g.name) }}</span>
          </span>
          <span class="GroupHeader__card-body">
            <span class="GroupHeader__card-name">{{ g.name }}</span>
            <span class="GroupHeader__card-meta">
              {{ g.isPrivate ? 'Private' : 'Public' }}
              ·
              {{ g.memberCount }} {{ g.memberCount === 1 ? 'member' : 'members' }}
            </span>
          </span>
          <svg
            v-if="g.isCurrent"
            class="GroupHeader__card-check"
            width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true"
          >
            <path d="M4.5 10.5L8 14L15.5 6" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </a>
      </div>
    </div>
  </Modal>
</template>
