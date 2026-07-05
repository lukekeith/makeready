<script setup lang="ts">
// NavBar — web twin of iOS Components/Navigation/NavBar.swift.
//
// The app's bottom tab bar: a fixed row of six equal-width tabs —
// Home / Groups / Library / Calendar / Search / Profile — laid out
// HStack(spacing:0), each `.frame(maxWidth:.infinity)`. The first five are an
// icon (22×22 template-rendered Image asset) over a 10pt label; Profile is a
// 22pt circular avatar over its label.
//
// Active tab = brandPrimary (#6c47ff) icon + label; inactive = white@70%.
// The five tab glyphs are the iOS Image assets (IconHome/People/Library/
// Calendar/Search) transcribed verbatim as inline SVG, drawn `currentColor` so
// the SCSS tints them per active/inactive state (faint 0.12 fills preserved,
// matching iOS template rendering keeping the asset's alpha).
//
// Profile avatar mirrors iOS CachedAsyncImage in the isolated snapshot:
//   • avatarMode 'fallback' (no URL)  → gray@30% circle + a small white@60%
//     person.crop.circle.fill glyph (size·0.4 ≈ 9px).
//   • avatarMode 'loading'  (URL set) → the remote photo never resolves in the
//     isolated snapshot, so CachedAsyncImage shows its ProgressView spinner; the
//     twin renders a frozen gray spoke spinner (no gray circle behind it).
// When Profile is the active tab, a 1.5px brandPrimary ring strokes the avatar
// circle (iOS `.overlay(Circle().stroke(selectedColor, lineWidth: 1.5))`).
//
// Only the variant-varying data travels via props (activeTab, avatarMode); the
// six-tab structure + glyphs are intrinsic to the bar.

import { computed } from 'vue'
import Avatar from '../../primitive/avatar/avatar.vue'

interface Props {
  activeTab?: 'home' | 'groups' | 'library' | 'calendar' | 'search' | 'profile' | ''
  // Production: the signed-in user's avatar — rendered via the Avatar component
  // (photo → initials). When neither is supplied (the isolated compare snapshot,
  // where iOS CachedAsyncImage never resolves), the bespoke `avatarMode` states
  // below stand in: a person-glyph fallback or a frozen ProgressView spinner —
  // which the live Avatar can't reproduce (it would load the image / animate).
  avatarUrl?: string | null
  avatarInitials?: string
  avatarMode?: 'fallback' | 'loading'
}

const props = withDefaults(defineProps<Props>(), {
  activeTab: '',
  avatarUrl: null,
  avatarInitials: '',
  avatarMode: 'fallback',
})

// Real identity → use the Avatar component; otherwise fall back to the
// snapshot-only states driven by avatarMode.
const hasAvatar = computed(() => Boolean(props.avatarUrl || props.avatarInitials))

// Additive: lets a host (e.g. the leader app shell) route on tab taps. Display-
// only / compare usages simply omit the listener and the bar stays static.
type NavTab = 'home' | 'groups' | 'library' | 'calendar' | 'search' | 'profile'
const emit = defineEmits<{ (e: 'select', tab: NavTab): void }>()

// 12 spoke angles for the frozen iOS ProgressView spinner (brightest leading,
// tapering clockwise) — same construction as CardSpinnerOverlay's twin.
const spokes = [
  { a: 0, o: 1 },
  { a: 30, o: 0.9 },
  { a: 60, o: 0.8 },
  { a: 90, o: 0.7 },
  { a: 120, o: 0.6 },
  { a: 150, o: 0.5 },
  { a: 180, o: 0.45 },
  { a: 210, o: 0.4 },
  { a: 240, o: 0.4 },
  { a: 270, o: 0.4 },
  { a: 300, o: 0.4 },
  { a: 330, o: 0.4 },
]
</script>

<template>
  <nav class="NavBar" aria-label="Primary">
    <!-- Home -->
    <span class="NavBar__col" :class="{ 'NavBar__col--active': props.activeTab === 'home' }" @click="emit('select', 'home')">
      <span class="NavBar__icon">
        <svg viewBox="0 0 24 24" fill="none">
          <path
            d="M3 10.5638C3 9.98948 3 9.7023 3.07403 9.43783C3.1396 9.20356 3.24737 8.98322 3.39203 8.78764C3.55534 8.56683 3.78202 8.39052 4.23539 8.0379L11.0177 2.76278C11.369 2.48953 11.5447 2.3529 11.7387 2.30038C11.9098 2.25404 12.0902 2.25404 12.2613 2.30038C12.4553 2.3529 12.631 2.48953 12.9823 2.76278L19.7646 8.03791C20.218 8.39052 20.4447 8.56683 20.608 8.78764C20.7526 8.98322 20.8604 9.20356 20.926 9.43783C21 9.7023 21 9.98948 21 10.5638V17.7988C21 18.9189 21 19.4789 20.782 19.9067C20.5903 20.2831 20.2843 20.589 19.908 20.7808C19.4802 20.9988 18.9201 20.9988 17.8 20.9988H6.2C5.07989 20.9988 4.51984 20.9988 4.09202 20.7808C3.71569 20.589 3.40973 20.2831 3.21799 19.9067C3 19.4789 3 18.9189 3 17.7988V10.5638Z"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </span>
      <span class="NavBar__label">Home</span>
    </span>

    <!-- Groups -->
    <span class="NavBar__col" :class="{ 'NavBar__col--active': props.activeTab === 'groups' }" @click="emit('select', 'groups')">
      <span class="NavBar__icon">
        <svg viewBox="0 0 24 24" fill="none">
          <g opacity="0.12">
            <path d="M9.50081 12C11.9861 12 14.0008 9.98528 14.0008 7.5C14.0008 5.01472 11.9861 3 9.50081 3C7.01553 3 5.00081 5.01472 5.00081 7.5C5.00081 9.98528 7.01553 12 9.50081 12Z" fill="currentColor" />
            <path d="M9.50081 15C6.67019 15 4.15435 16.5446 2.56004 18.9383C2.21078 19.4628 2.03614 19.725 2.05625 20.0599C2.0719 20.3207 2.24286 20.64 2.45125 20.7976C2.71889 21 3.08698 21 3.82317 21H15.1785C15.9146 21 16.2827 21 16.5504 20.7976C16.7588 20.64 16.9297 20.3207 16.9454 20.0599C16.9655 19.725 16.7909 19.4628 16.4416 18.9383C14.8473 16.5446 12.3314 15 9.50081 15Z" fill="currentColor" />
          </g>
          <path
            d="M18.0008 15.8369C19.4567 16.5683 20.7049 17.742 21.6161 19.2096C21.7965 19.5003 21.8867 19.6456 21.9179 19.8468C21.9813 20.2558 21.7016 20.7585 21.3207 20.9204C21.1333 21 20.9225 21 20.5008 21M16.0008 11.5322C17.4825 10.7959 18.5008 9.26686 18.5008 7.5C18.5008 5.73314 17.4825 4.20411 16.0008 3.46776M14.0008 7.5C14.0008 9.98528 11.9861 12 9.50081 12C7.01553 12 5.00081 9.98528 5.00081 7.5C5.00081 5.01472 7.01553 3 9.50081 3C11.9861 3 14.0008 5.01472 14.0008 7.5ZM2.56004 18.9383C4.15435 16.5446 6.67019 15 9.50081 15C12.3314 15 14.8473 16.5446 16.4416 18.9383C16.7909 19.4628 16.9655 19.725 16.9454 20.0599C16.9297 20.3207 16.7588 20.64 16.5504 20.7976C16.2827 21 15.9146 21 15.1785 21H3.82317C3.08698 21 2.71889 21 2.45125 20.7976C2.24286 20.64 2.0719 20.3207 2.05625 20.0599C2.03614 19.725 2.21078 19.4628 2.56004 18.9383Z"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </span>
      <span class="NavBar__label">Groups</span>
    </span>

    <!-- Library -->
    <span class="NavBar__col" :class="{ 'NavBar__col--active': props.activeTab === 'library' }" @click="emit('select', 'library')">
      <span class="NavBar__icon">
        <svg viewBox="0 0 24 24" fill="none">
          <path
            d="M12 21L11.8999 20.8499C11.2053 19.808 10.858 19.287 10.3991 18.9098C9.99286 18.5759 9.52476 18.3254 9.02161 18.1726C8.45325 18 7.82711 18 6.57482 18H5.2C4.07989 18 3.51984 18 3.09202 17.782C2.71569 17.5903 2.40973 17.2843 2.21799 16.908C2 16.4802 2 15.9201 2 14.8V6.2C2 5.07989 2 4.51984 2.21799 4.09202C2.40973 3.71569 2.71569 3.40973 3.09202 3.21799C3.51984 3 4.07989 3 5.2 3H5.6C7.84021 3 8.96031 3 9.81596 3.43597C10.5686 3.81947 11.1805 4.43139 11.564 5.18404C12 6.03968 12 7.15979 12 9.4M12 21V9.4M12 21L12.1001 20.8499C12.7947 19.808 13.142 19.287 13.6009 18.9098C14.0071 18.5759 14.4752 18.3254 14.9784 18.1726C15.5467 18 16.1729 18 17.4252 18H18.8C19.9201 18 20.4802 18 20.908 17.782C21.2843 17.5903 21.5903 17.2843 21.782 16.908C22 16.4802 22 15.9201 22 14.8V6.2C22 5.07989 22 4.51984 21.782 4.09202C21.5903 3.71569 21.2843 3.40973 20.908 3.21799C20.4802 3 19.9201 3 18.8 3H18.4C16.1598 3 15.0397 3 14.184 3.43597C13.4314 3.81947 12.8195 4.43139 12.436 5.18404C12 6.03968 12 7.15979 12 9.4"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </span>
      <span class="NavBar__label">Library</span>
    </span>

    <!-- Calendar -->
    <span class="NavBar__col" :class="{ 'NavBar__col--active': props.activeTab === 'calendar' }" @click="emit('select', 'calendar')">
      <span class="NavBar__icon">
        <svg viewBox="0 0 24 24" fill="none">
          <path opacity="0.12" d="M3 8.8C3 7.11984 3 6.27976 3.32698 5.63803C3.6146 5.07354 4.07354 4.6146 4.63803 4.32698C5.27976 4 6.11984 4 7.8 4H16.2C17.8802 4 18.7202 4 19.362 4.32698C19.9265 4.6146 20.3854 5.07354 20.673 5.63803C21 6.27976 21 7.11984 21 8.8V10H3V8.8Z" fill="currentColor" />
          <path
            d="M21 10H3M16 2V6M8 2V6M7.8 22H16.2C17.8802 22 18.7202 22 19.362 21.673C19.9265 21.3854 20.3854 20.9265 20.673 20.362C21 19.7202 21 18.8802 21 17.2V8.8C21 7.11984 21 6.27976 20.673 5.63803C20.3854 5.07354 19.9265 4.6146 19.362 4.32698C18.7202 4 17.8802 4 16.2 4H7.8C6.11984 4 5.27976 4 4.63803 4.32698C4.07354 4.6146 3.6146 5.07354 3.32698 5.63803C3 6.27976 3 7.11984 3 8.8V17.2C3 18.8802 3 19.7202 3.32698 20.362C3.6146 20.9265 4.07354 21.3854 4.63803 21.673C5.27976 22 6.11984 22 7.8 22Z"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </span>
      <span class="NavBar__label">Calendar</span>
    </span>

    <!-- Search -->
    <span class="NavBar__col" :class="{ 'NavBar__col--active': props.activeTab === 'search' }" @click="emit('select', 'search')">
      <span class="NavBar__icon">
        <svg viewBox="0 0 24 24" fill="none">
          <path
            d="M21 21L16.65 16.65M19 11C19 15.4183 15.4183 19 11 19C6.58172 19 3 15.4183 3 11C3 6.58172 6.58172 3 11 3C15.4183 3 19 6.58172 19 11Z"
            stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </span>
      <span class="NavBar__label">Search</span>
    </span>

    <!-- Profile (avatar) -->
    <span class="NavBar__col" :class="{ 'NavBar__col--active': props.activeTab === 'profile' }" @click="emit('select', 'profile')">
      <span class="NavBar__avatar">
        <!-- Production: the real signed-in avatar via the Avatar component. -->
        <Avatar
          v-if="hasAvatar"
          class="NavBar__avatarImg"
          :src="props.avatarUrl || undefined"
          :initials="props.avatarInitials || undefined"
          alt="Profile"
        />
        <!-- No identity (isolated compare snapshot): gray circle + person glyph. -->
        <span v-else-if="props.avatarMode === 'fallback'" class="NavBar__avatarFallback">
          <svg class="NavBar__person" viewBox="0 0 24 24" fill="currentColor">
            <circle cx="12" cy="8.2" r="3.7" />
            <path d="M12 13.4c-3.5 0-6.4 2-6.4 4.8 0 .6.4 1 1 1h10.8c.6 0 1-.4 1-1 0-2.8-2.9-4.8-6.4-4.8Z" />
          </svg>
        </span>
        <!-- URL set but unresolved in snapshot → frozen spoke spinner. -->
        <span v-else class="NavBar__spinner">
          <svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.4" stroke-linecap="round">
            <line
              v-for="s in spokes"
              :key="s.a"
              x1="12" y1="4.5" x2="12" y2="8.5"
              :opacity="s.o"
              :transform="`rotate(${s.a} 12 12)`" />
          </svg>
        </span>
        <!-- Active Profile → brandPrimary 1.5px ring on the circle edge. -->
        <span v-if="props.activeTab === 'profile'" class="NavBar__avatarRing" />
      </span>
      <span class="NavBar__label">Profile</span>
    </span>
  </nav>
</template>
