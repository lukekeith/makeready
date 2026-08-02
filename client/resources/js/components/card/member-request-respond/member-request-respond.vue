<script lang="ts">
// MemberRequestRespond — twin of iPhone MemberRequestRespondModal.swift
// (Route.memberRequestRespond: topLevel 300, RAW chrome — the modal ships its
// own presentation). Full-screen opaque appBackground wash (NOT a translucent
// black scrim — that's managed-modal's look) with a centered VStack(32):
// member name (s24Bold) over the verbatim continuation sentence
// "has submitted a request to join {group} on {date} at {time}." (LOWERCASE
// start — it continues the name line; never sentence-case it), then three
// full-width 48px r8 buttons with CENTERED s12Bold labels (no h-padding):
// Approve (brand) / Reject (white@0.1) / Cancel (white@0.5 on white@0.05).
//
// Tap-outside is SWALLOWED on iOS (background .onTapGesture {}) — the wash
// deliberately binds nothing. Enter/exit animation + dismiss-then-act
// sequencing belong to the production host, not this twin.
export interface MemberRequestRespondProps {
  memberName: string
  groupName: string
  /** Pre-formatted iOS DateFormatters.fullMonthDayYear — "MMMM d, yyyy". */
  dateLabel: string
  /** Pre-formatted iOS DateFormatters.time12Hour — "h:mm a". */
  timeLabel: string
}
</script>

<script setup lang="ts">
withDefaults(defineProps<MemberRequestRespondProps & { statusBar?: boolean }>(), {
  statusBar: false,
})

const emit = defineEmits<{
  approve: []
  reject: []
  cancel: []
}>()
</script>

<template>
  <div class="MemberRequestRespond">
    <div v-if="statusBar" class="MemberRequestRespond__statusbar" aria-hidden="true">
      <span class="MemberRequestRespond__clock">9:41</span>
    </div>

    <div class="MemberRequestRespond__content">
      <div class="MemberRequestRespond__title">
        <h2 class="MemberRequestRespond__name">{{ memberName }}</h2>
        <p class="MemberRequestRespond__sentence">
          has submitted a request to join {{ groupName }} on {{ dateLabel }} at {{ timeLabel }}.
        </p>
      </div>

      <div class="MemberRequestRespond__buttons">
        <button
          type="button"
          class="MemberRequestRespond__button MemberRequestRespond__button--approve"
          @click="emit('approve')"
        >
          Approve
        </button>
        <button
          type="button"
          class="MemberRequestRespond__button MemberRequestRespond__button--reject"
          @click="emit('reject')"
        >
          Reject
        </button>
        <button
          type="button"
          class="MemberRequestRespond__button MemberRequestRespond__button--cancel"
          @click="emit('cancel')"
        >
          Cancel
        </button>
      </div>
    </div>
  </div>
</template>
