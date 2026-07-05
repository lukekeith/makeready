<script setup lang="ts">
// GroupInvite — twin of iPhone Pages/Manage/Group/GroupInvitePage.swift, the
// group-home modal's TRAILING SlideStack pane (paperplane / Invite button).
//
// NOT the org-wide ShareInviteSheet: this screen renders the plain 512px
// black-on-white server QR (GET /api/groups/:id/invite qrCode data URL)
// directly, shows the group code in a purple-bordered card, and shares
// TEXT+URL (never the QR image). Layout (ScrollView VStack(24) pad-h16
// pad-top24): code card → 264px white QR card + caption → three BoxButtons
// (Share Invite primary / Copy Invite Link / Invite friends) → spacer 40.
// The "Copied to clipboard" toast pill is page-owned on iOS, so the twin
// renders it from a `toast` prop (capture can seed it as a variant).
import PageTitle from '../page-title/page-title.vue'
import BoxButton from '../box-button/box-button.vue'

interface Props {
  groupName?: string
  code?: string
  /** Server QR data URL (deterministic for a fixed code); empty → gray spinner. */
  qrCode?: string
  loading?: boolean
  errorMessage?: string
  /** Shows the bottom "Copied to clipboard" toast pill. */
  toast?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  groupName: '',
  code: '',
  qrCode: '',
  loading: false,
  errorMessage: '',
  toast: false,
})

const emit = defineEmits<{
  back: []
  copyCode: []
  joinPage: []
  share: []
  copyLink: []
  inviteFriends: []
  retry: []
}>()

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'
// SF "doc.on.doc" — two offset document sheets.
const DOC_ON_DOC =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="7" width="11.5" height="14" rx="2.4"/><path d="M15.8 4H7.2A2.7 2.7 0 0 0 4.5 6.7v10.6"/></svg>'
// SF "square.and.arrow.up" — verbatim from the LessonActionMenu adapter.
const SHARE_UP =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V4M8 8l4-4 4 4"/><path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>'
// SF "link" — chain links.
const LINK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7.1-7.1l-1.7 1.7"/><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7.1 7.1l1.7-1.7"/></svg>'
// SF "person.badge.plus" — person with a plus badge.
const PERSON_BADGE_PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="10.5" cy="7.5" r="3.4"/><path d="M4 19.6c0-3.4 2.9-5.8 6.5-5.8 1.2 0 2.3.26 3.3.72"/><path d="M18 14v6M15 17h6"/></svg>'
// SF "exclamationmark.triangle" — error glyph.
const WARN_TRIANGLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.5 1.9 20.5h20.2z"/><path d="M12 9.5v5"/><circle cx="12" cy="17.4" r="0.4" fill="currentColor"/></svg>'
</script>

<template>
  <div class="GroupInvite">
    <PageTitle
      class="GroupInvite__title"
      title="Group Invite"
      :left-icon="BACK_CHEVRON"
      @left="emit('back')"
    />

    <!-- Loading (rare — the invite is prefetched by the group home) -->
    <div v-if="loading" class="GroupInvite__state">
      <span class="GroupInvite__stateSpinner" aria-label="Loading" />
    </div>

    <!-- Error (only when nothing is cached) -->
    <div v-else-if="errorMessage" class="GroupInvite__state GroupInvite__state--error">
      <span class="GroupInvite__errorGlyph" aria-hidden="true" v-html="WARN_TRIANGLE" />
      <p class="GroupInvite__errorTitle">Failed to load invite</p>
      <p class="GroupInvite__errorMessage">{{ errorMessage }}</p>
      <BoxButton
        class="GroupInvite__retry"
        label="Try Again"
        variant="secondary"
        size="md"
        @click="emit('retry')"
      />
    </div>

    <div v-else class="GroupInvite__scroll">
      <!-- Group code card (r12, brand@0.2 2px stroke) -->
      <div class="GroupInvite__codeCard">
        <div class="GroupInvite__codeRow">
          <span class="GroupInvite__code">{{ code }}</span>
          <button
            type="button"
            class="GroupInvite__copyCode"
            aria-label="Copy code"
            v-html="DOC_ON_DOC"
            @click="emit('copyCode')"
          ></button>
        </div>
        <div class="GroupInvite__instruction">
          <span class="GroupInvite__instructionText">Use this code at</span>
          <button type="button" class="GroupInvite__joinLink" @click="emit('joinPage')">
            app.makeready.org/join/group
          </button>
        </div>
      </div>

      <!-- QR (264px white card, 240px code, crisp scaling) -->
      <div class="GroupInvite__qrSection">
        <div class="GroupInvite__qrCard">
          <img v-if="qrCode" class="GroupInvite__qr" :src="qrCode" alt="Group invite QR code" />
          <span v-else class="GroupInvite__qrSpinner" aria-label="Loading QR" />
        </div>
        <p class="GroupInvite__qrCaption">Scan to join {{ groupName }}</p>
      </div>

      <!-- Actions -->
      <div class="GroupInvite__actions">
        <BoxButton label="Share Invite" :icon="SHARE_UP" icon-position="left" variant="primary" size="lg" full-width @click="emit('share')" />
        <BoxButton label="Copy Invite Link" :icon="LINK" icon-position="left" variant="secondary" size="lg" full-width @click="emit('copyLink')" />
        <BoxButton label="Invite friends" :icon="PERSON_BADGE_PLUS" icon-position="left" variant="secondary" size="lg" full-width @click="emit('inviteFriends')" />
      </div>

      <div class="GroupInvite__bottom-spacer" />
    </div>

    <!-- "Copied to clipboard" toast (bottom pill, move+opacity 2s on iOS) -->
    <Transition name="GroupInvite-toast">
      <div v-if="toast" class="GroupInvite__toast">Copied to clipboard</div>
    </Transition>
  </div>
</template>
