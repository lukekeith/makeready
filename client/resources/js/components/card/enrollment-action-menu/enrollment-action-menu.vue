<script setup lang="ts">
// EnrollmentActionMenu — web twin of iPhone
// Components/Navigation/EnrollmentActionMenu.swift, presented as the
// `.enrollmentActionMenu` menu (ManagedMenuView chrome).
//
// Header = study name only (no subtitle, unlike LessonActionMenu). Two modes
// on `canManage`: manage rows (Edit lessons / Edit enrollment / Preview
// study) in one white@5% r8 card, or the FYI note card + a standalone
// Preview card. Close = xmark s20Medium, padV32.
interface Props {
  studyName: string
  canManage?: boolean
  /** Program creator name for the FYI copy; absent → the anonymous variant. */
  creatorName?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  canManage: true,
  creatorName: '',
})

const emit = defineEmits<{
  editLessons: []
  editEnrollment: []
  preview: []
  close: []
}>()

const LIST_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M8.5 6h12M8.5 12h12M8.5 18h12"/><circle cx="4" cy="6" r="1" fill="currentColor" stroke="none"/><circle cx="4" cy="12" r="1" fill="currentColor" stroke="none"/><circle cx="4" cy="18" r="1" fill="currentColor" stroke="none"/></svg>'
const SLIDERS_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M3 7h6M13 7h8M3 12h10M17 12h4M3 17h4M11 17h10"/><circle cx="11" cy="7" r="2"/><circle cx="15" cy="12" r="2"/><circle cx="9" cy="17" r="2"/></svg>'
const EYE_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
const INFO_ICON =
  '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="10"/><path d="M12 7.2a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 0 1 0-2.2zM11 11h2v6h-2z" fill="#0d101a"/></svg>'
const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3.5 3.5l13 13M16.5 3.5l-13 13"/></svg>'

const fyiText = props.creatorName
  ? `This study was created by ${props.creatorName} and can only be edited by them. Contact ${props.creatorName} if changes are needed.`
  : 'This study was created by another leader in your organization and can only be edited by them. Contact that leader if changes are needed.'
</script>

<template>
  <div :class="['EnrollmentActionMenu', props.class]">
    <div class="EnrollmentActionMenu__header">
      <span class="EnrollmentActionMenu__study">{{ props.studyName }}</span>
    </div>

    <template v-if="props.canManage">
      <div class="EnrollmentActionMenu__group">
        <button
          type="button"
          class="EnrollmentActionMenu__item"
          @click="emit('editLessons')"
        >
          <span class="EnrollmentActionMenu__itemIcon" v-html="LIST_ICON"></span>
          <span class="EnrollmentActionMenu__itemLabel">Edit lessons</span>
        </button>
        <button
          type="button"
          class="EnrollmentActionMenu__item"
          @click="emit('editEnrollment')"
        >
          <span class="EnrollmentActionMenu__itemIcon" v-html="SLIDERS_ICON"></span>
          <span class="EnrollmentActionMenu__itemLabel">Edit enrollment</span>
        </button>
        <button
          type="button"
          class="EnrollmentActionMenu__item"
          @click="emit('preview')"
        >
          <span class="EnrollmentActionMenu__itemIcon" v-html="EYE_ICON"></span>
          <span class="EnrollmentActionMenu__itemLabel">Preview study</span>
        </button>
      </div>
    </template>

    <template v-else>
      <div class="EnrollmentActionMenu__readonly">
        <div class="EnrollmentActionMenu__fyi">
          <span class="EnrollmentActionMenu__fyiIcon" v-html="INFO_ICON"></span>
          <span class="EnrollmentActionMenu__fyiText">{{ fyiText }}</span>
        </div>
        <div class="EnrollmentActionMenu__group EnrollmentActionMenu__group--single">
          <button
            type="button"
            class="EnrollmentActionMenu__item"
            @click="emit('preview')"
          >
            <span class="EnrollmentActionMenu__itemIcon" v-html="EYE_ICON"></span>
            <span class="EnrollmentActionMenu__itemLabel">Preview study</span>
          </button>
        </div>
      </div>
    </template>

    <button type="button" class="EnrollmentActionMenu__close" @click="emit('close')">
      <span v-html="XMARK"></span>
    </button>
  </div>
</template>
