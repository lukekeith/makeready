<script lang="ts">
// MemberProfile — twin of iPhone Pages/Manage/Member/MemberProfilePage.swift.
// Full-bleed hero modal: photo (or 240px initials circle) under an ALWAYS-on
// #0d101a gradient, name at 45% of the modal height, three circleBlur actions,
// keyValue + data InfoPanels, CardGroup rows (removed = 50% dim + undimmed
// #df1439 1.5px border — done via a wrapper so CardGroup stays untouched).
//
// Data-driven: every string arrives pre-formatted (dates/phone formatted by
// the store in production, by the adapter/fixture in capture). Emits are bound
// only by production; the compare harness binds nothing.
//
// iOS quirks mirrored: gradient never conditional; Phone row renders whenever
// the profile is loaded (even empty); BOTH data rows tappable → purple values;
// chevron back only when `showBack` (GlobalSearch entry — not members lists).
export interface MemberProfileGroup {
  id: string
  name: string
  imageUrl?: string
  /** relativeDuration string — "today" / "3d" / "2mo" / "1yr" / "2yrs" */
  number: string
  /** "Joined Jun 30, 2026 at 7:30 AM" / "Removed …" */
  dateLabel: string
  removed?: boolean
}
</script>

<script setup lang="ts">
import { computed } from 'vue'
import ActionButton from '../action-button/action-button.vue'
import InfoPanel, { type InfoPanelItem } from '../info-panel/info-panel.vue'
import CardGroup from '../card-group/card-group.vue'

interface Props {
  /** displayName (profile ?? seed). Hidden when empty. */
  name?: string
  /** Hero photo; absent → initials circle (iOS hasPhoto). */
  avatarUrl?: string
  /** profile != nil — gates actions/panels/cards (name+hero render from seed). */
  loaded?: boolean
  /** Pre-formatted "MMM d, yyyy" earliest join date; omit → row omitted. */
  joined?: string
  /** Whole-years age string; omit → row omitted. */
  age?: string
  /** Pre-formatted phone. Row renders whenever loaded (iOS: always appended). */
  phone?: string
  /** displayEmail; omit → row omitted. */
  email?: string
  groups?: MemberProfileGroup[]
  loading?: boolean
  errorMessage?: string
  /** iOS: onDismiss chevron — only the GlobalSearch entry passes it. */
  showBack?: boolean
  /** Capture-only simulator status bar. Production never passes it. */
  statusBar?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  name: '',
  avatarUrl: '',
  loaded: true,
  joined: '',
  age: '',
  phone: undefined,
  email: '',
  groups: () => [],
  loading: false,
  errorMessage: '',
  showBack: false,
  statusBar: false,
})

const emit = defineEmits<{
  back: []
  text: []
  call: []
  addContact: []
  phoneTap: []
  emailTap: []
  groupTap: [string]
  retry: []
}>()

// iOS MemberProfilePage.hasPhoto
const hasPhoto = computed(() => !!props.avatarUrl)

// iOS MemberProfilePage.initials — first char of first + last word, uppercased.
const initials = computed(() => {
  const parts = props.name.split(' ').filter(Boolean)
  const first = parts[0]?.charAt(0) ?? ''
  const last = parts.length > 1 ? (parts[parts.length - 1]?.charAt(0) ?? '') : ''
  return (first + last).toUpperCase()
})

// iOS keyValueItems — panel omitted entirely when empty.
const keyValueItems = computed<InfoPanelItem[]>(() => {
  const items: InfoPanelItem[] = []
  if (props.joined) items.push({ label: 'Joined', value: props.joined })
  if (props.age) items.push({ label: 'Age', value: props.age })
  return items
})

// iOS dataItems — Phone always appended (value may be empty); Email when set.
// Both rows tappable → brandPrimary values (iOS InfoPanel.dataRowContent).
const dataItems = computed<InfoPanelItem[]>(() => {
  if (!props.loaded) return []
  const items: InfoPanelItem[] = [
    { label: 'Phone', value: props.phone ?? '', tappable: true },
  ]
  if (props.email) items.push({ label: 'Email', value: props.email, tappable: true })
  return items
})

const onDataRowTap = (i: number) => {
  if (dataItems.value[i]?.label === 'Phone') emit('phoneTap')
  else emit('emailTap')
}

// SF-symbol approximations (adapter-precedent inline SVGs, currentColor).
const BUBBLES =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 9.5a5 5 0 0 1 5-5h3a5 5 0 0 1 4.9 4M2.5 9.5v7l3-2h1"/><path d="M9 13.5a4.5 4.5 0 0 1 4.5-4.5h3.5a4.5 4.5 0 0 1 4.5 4.5v.5a4.5 4.5 0 0 1-4.5 4.5h-.5l-3.5 2.5v-2.5h.5A4.5 4.5 0 0 1 9 14z" fill="currentColor" stroke="none"/></svg>'
const PHONE_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.6 3.2c.6-.6 1.6-.5 2.1.2l1.9 2.7c.4.6.4 1.4-.1 1.9l-1 1.1c-.3.3-.3.8-.1 1.2a12.4 12.4 0 0 0 4.3 4.3c.4.2.9.2 1.2-.1l1.1-1c.5-.5 1.3-.5 1.9-.1l2.7 1.9c.7.5.8 1.5.2 2.1l-1.2 1.2c-.8.8-2 1.1-3.1.8-2.9-.8-5.6-2.4-7.9-4.7S4.7 9.6 3.9 6.7c-.3-1.1 0-2.3.8-3.1z"/></svg>'
const PERSON_PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="8" r="4"/><path d="M2.5 20.5c.8-3.3 3.9-5 7.5-5s6.7 1.7 7.5 5"/><path d="M19 5v6M16 8h6"/></svg>'
const CHEVRON_LEFT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 5.5 8 12l6.5 6.5"/></svg>'
const TRIANGLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.5 22 20H2z"/><path d="M12 9.5v5M12 17.2v.3"/></svg>'
</script>

<template>
  <div class="MemberProfile">
    <!-- Layer 1b — hero photo (object-fit cover, fades in via Motion.standard) -->
    <Transition name="MemberProfile-photo">
      <div v-if="hasPhoto" class="MemberProfile__photo" aria-hidden="true">
        <img :src="avatarUrl" alt="" />
      </div>
    </Transition>

    <!-- Layer 1c — gradient: ALWAYS present, never conditional (iOS comment) -->
    <div class="MemberProfile__gradient" aria-hidden="true"></div>

    <!-- Layer 1d — initials circle at 12% of the modal height -->
    <div v-if="!hasPhoto" class="MemberProfile__initials" aria-hidden="true">
      <span class="MemberProfile__initialsText">{{ initials }}</span>
    </div>

    <div v-if="statusBar" class="MemberProfile__statusbar" aria-hidden="true">
      <span class="MemberProfile__clock">9:41</span>
    </div>

    <!-- Layer 2 — scroll content; spacer = 45% of the modal box height -->
    <div class="MemberProfile__scroll">
      <div class="MemberProfile__spacer" aria-hidden="true"></div>
      <div class="MemberProfile__content">
        <h2 v-if="name" class="MemberProfile__name">{{ name }}</h2>

        <template v-if="loaded">
          <div class="MemberProfile__actions">
            <ActionButton variant="circleBlur" :icon="BUBBLES" @click="emit('text')" />
            <ActionButton variant="circleBlur" :icon="PHONE_FILL" @click="emit('call')" />
            <ActionButton variant="circleBlur" :icon="PERSON_PLUS" @click="emit('addContact')" />
          </div>

          <InfoPanel
            v-if="keyValueItems.length"
            class="MemberProfile__panel"
            mode="keyValue"
            :items="keyValueItems"
          />

          <InfoPanel
            v-if="dataItems.length"
            class="MemberProfile__panel"
            mode="data"
            :items="dataItems"
            @row-tap="onDataRowTap"
          />

          <div v-if="groups.length" class="MemberProfile__groups">
            <div
              v-for="g in groups"
              :key="g.id"
              class="MemberProfile__cardWrap"
              :class="g.removed && 'MemberProfile__cardWrap--removed'"
            >
              <CardGroup
                :name="g.name"
                :image-url="g.imageUrl"
                icon-fallback
                :member-count="0"
                :metadata="[{ number: g.number, label: g.dateLabel }]"
                @click="emit('groupTap', g.id)"
              />
            </div>
          </div>
        </template>
      </div>
    </div>

    <!-- Layer 3 — loading (iOS: unreachable from seeded entries; built anyway) -->
    <div v-if="loading" class="MemberProfile__loading">
      <span class="MemberProfile__spinner" aria-label="Loading" />
    </div>

    <!-- Layer 4 — error (only when profile failed to load) -->
    <div v-else-if="errorMessage" class="MemberProfile__error">
      <span class="MemberProfile__errorGlyph" aria-hidden="true" v-html="TRIANGLE" />
      <p class="MemberProfile__errorText">{{ errorMessage }}</p>
      <button type="button" class="MemberProfile__retry" @click="emit('retry')">
        Try Again
      </button>
    </div>

    <!-- Back chevron — GlobalSearch entry only -->
    <button
      v-if="showBack"
      type="button"
      class="MemberProfile__back"
      aria-label="Back"
      @click="emit('back')"
    >
      <span class="MemberProfile__backIcon" aria-hidden="true" v-html="CHEVRON_LEFT" />
    </button>
  </div>
</template>
