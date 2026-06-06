<script setup lang="ts">
import { ref } from 'vue'
import Modal from '../../primitive/modal/modal.vue'
import './group-switcher-island.scss'

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
// the header renders as a static (non-interactive) panel without a chevron.
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
    class="GroupSwitcher__current"
    :class="{ 'GroupSwitcher__current--static': !canSwitch }"
    :aria-haspopup="canSwitch ? 'dialog' : undefined"
    @click="open"
  >
    <div class="GroupSwitcher__title">
      <span class="GroupSwitcher__name">{{ current.name }}</span>
      <svg
        v-if="canSwitch"
        class="GroupSwitcher__chevron"
        width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true"
      >
        <path d="M5 7.5L10 12.5L15 7.5" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </div>

    <p v-if="current.orgName" class="GroupSwitcher__org">{{ current.orgName }}</p>

    <div class="GroupSwitcher__meta">
      <span class="GroupSwitcher__privacy">
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true">
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
      <span class="GroupSwitcher__count">
        {{ current.memberCount }} {{ current.memberCount === 1 ? 'member' : 'members' }}
      </span>
    </div>
  </component>

  <Modal
    v-if="canSwitch"
    :is-open="isOpen"
    mode="Menu"
    aria-title="Switch group"
    aria-description="Choose a group to view"
    @close="close"
  >
    <div class="GroupSwitcher__menu">
      <p class="GroupSwitcher__menu-title">Your groups</p>
      <div class="GroupSwitcher__list">
        <a
          v-for="g in groups"
          :key="g.id"
          class="GroupSwitcher__card"
          :class="{ 'GroupSwitcher__card--current': g.isCurrent }"
          :href="g.href"
          :aria-current="g.isCurrent ? 'true' : undefined"
        >
          <span class="GroupSwitcher__card-cover">
            <img v-if="g.coverImageUrl" :src="g.coverImageUrl" alt="" />
            <span v-else class="GroupSwitcher__card-initial">{{ initial(g.name) }}</span>
          </span>
          <span class="GroupSwitcher__card-body">
            <span class="GroupSwitcher__card-name">{{ g.name }}</span>
            <span class="GroupSwitcher__card-meta">
              {{ g.isPrivate ? 'Private' : 'Public' }}
              ·
              {{ g.memberCount }} {{ g.memberCount === 1 ? 'member' : 'members' }}
            </span>
          </span>
          <svg
            v-if="g.isCurrent"
            class="GroupSwitcher__card-check"
            width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true"
          >
            <path d="M4.5 10.5L8 14L15.5 6" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </a>
      </div>
    </div>
  </Modal>
</template>
