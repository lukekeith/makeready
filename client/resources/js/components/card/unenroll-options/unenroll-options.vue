<script setup lang="ts">
// UnenrollOptions — web twin of iPhone UnenrollOptionsModal
// (Pages/Manage/Group/Enrollment/UnenrollOptionsModal.swift), presented as
// the `.unenrollOptions` modal (tap-outside DOES dismiss).
//
// A 4-phase machine: loading → options → confirm → error (phase changes are
// Motion.micro on iOS). Options branches on canFullyUnenroll: the full-remove
// card is live (destructive) when no member data exists, else the
// cancel-future card is offered and full removal renders as an inert
// white@20% block. Strings verbatim from Swift.
import { computed } from 'vue'

interface Props {
  phase?: 'loading' | 'options' | 'confirm' | 'error'
  programName?: string
  programImageUrl?: string
  totalLessons?: number
  lessonsWithData?: number
  cleanLessons?: number
  canFullyUnenroll?: boolean
  /** Which option the confirm phase shows. */
  confirmMode?: 'fullRemoval' | 'cancelFuture'
  errorMessage?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  phase: 'options',
  programName: 'Study Program',
  programImageUrl: '',
  totalLessons: 0,
  lessonsWithData: 0,
  cleanLessons: 0,
  canFullyUnenroll: true,
  confirmMode: 'fullRemoval',
  errorMessage: '',
})

const emit = defineEmits<{
  dismiss: []
  back: []
  selectFullRemoval: []
  selectCancelFuture: []
  proceed: []
  retry: []
}>()

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3.5 3.5l13 13M16.5 3.5l-13 13"/></svg>'
const CHEVRON_LEFT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 5l-7 7 7 7"/></svg>'
const BOOK_FILL =
  '<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 1.783C7.015.936 5.587.81 4.287.94c-1.514.153-3.042.672-4.013 1.448a.5.5 0 0 0-.274.446v11a.5.5 0 0 0 .727.446c.93-.468 2.34-.948 3.658-1.08 1.323-.133 2.452.063 3.072.638a.5.5 0 0 0 .654 0c.62-.575 1.75-.771 3.072-.638 1.318.132 2.728.612 3.658 1.08A.5.5 0 0 0 16 13.834v-11a.5.5 0 0 0-.274-.446c-.97-.776-2.499-1.295-4.013-1.448C10.413.809 8.985.936 8 1.783"/></svg>'
const CHECK_CIRCLE_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="10"/><path d="M7.5 12.5l3 3 6-7" fill="none" stroke="#0d101a" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
const WARNING_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.5L1.5 20.5h21L12 2.5z"/><path d="M12 9.5v4.5M12 16.8v.4" fill="none" stroke="#0d101a" stroke-width="1.8" stroke-linecap="round"/></svg>'
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'
const TRASH_CIRCLE_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="11"/><g fill="none" stroke="#0d101a" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7.5 8.5h9"/><path d="M10 8.5V7.6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v.9"/><path d="M8.6 8.5l.7 8a1.4 1.4 0 0 0 1.4 1.3h2.6a1.4 1.4 0 0 0 1.4-1.3l.7-8"/></g></svg>'
const CALENDAR_MINUS =
  '<svg viewBox="0 0 26 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4.5" width="17" height="16.5" rx="2.5"/><path d="M6.5 2.5v4M14.5 2.5v4M2 9.5h17"/><circle cx="22" cy="6" r="3.4"/><path d="M20.4 6h3.2"/></svg>'
const CHEVRON_RIGHT =
  '<svg viewBox="0 0 9 15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1.5 1.5l6 6-6 6"/></svg>'
const WARNING_OUTLINE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3L1.8 20.5h20.4L12 3z"/><path d="M12 10v4.5"/><circle cx="12" cy="17.5" r="0.6" fill="currentColor"/></svg>'

const bannerText = computed(() =>
  props.canFullyUnenroll
    ? 'No members have submitted responses yet'
    : `${props.lessonsWithData} of ${props.totalLessons} lessons have member responses`
)

const fullRemovalDesc = computed(
  () =>
    `All ${props.totalLessons} scheduled lessons will be removed. No member data will be lost.`
)

const cancelFutureDesc = computed(
  () =>
    `Remove ${props.cleanLessons} upcoming lessons with no member data. ${props.lessonsWithData} lessons with responses will be preserved.`
)

const confirmTitle = computed(() =>
  props.confirmMode === 'fullRemoval' ? 'Remove Enrollment' : 'Cancel Future Lessons'
)

const confirmDescription = computed(() =>
  props.confirmMode === 'fullRemoval'
    ? `This will remove all ${props.totalLessons} scheduled lessons from ${props.programName}. This action cannot be undone.`
    : `This will remove ${props.cleanLessons} upcoming lessons with no member data from ${props.programName}. ${props.lessonsWithData} lessons with member responses will be preserved.`
)
</script>

<template>
  <div :class="['UnenrollOptions', props.class]">
    <!-- Loading -->
    <div v-if="props.phase === 'loading'" class="UnenrollOptions__loading">
      <span class="UnenrollOptions__spinner" aria-hidden="true"></span>
      <span class="UnenrollOptions__loadingText">Checking enrollment status...</span>
    </div>

    <!-- Error -->
    <template v-else-if="props.phase === 'error'">
      <div class="UnenrollOptions__dragSpacer"></div>
      <div class="UnenrollOptions__titleBar">
        <button type="button" class="UnenrollOptions__iconBtn" @click="emit('dismiss')">
          <span v-html="XMARK"></span>
        </button>
        <span class="UnenrollOptions__title">Unenroll</span>
      </div>
      <div class="UnenrollOptions__stateBlock">
        <span class="UnenrollOptions__stateIcon" v-html="WARNING_OUTLINE"></span>
        <span class="UnenrollOptions__stateText">{{ props.errorMessage }}</span>
        <button type="button" class="UnenrollOptions__retry" @click="emit('retry')">
          Try Again
        </button>
      </div>
    </template>

    <!-- Confirm -->
    <template v-else-if="props.phase === 'confirm'">
      <div class="UnenrollOptions__dragSpacer"></div>
      <div class="UnenrollOptions__titleBar">
        <button type="button" class="UnenrollOptions__iconBtn" @click="emit('back')">
          <span v-html="CHEVRON_LEFT"></span>
        </button>
        <span class="UnenrollOptions__title">Confirm</span>
      </div>
      <div class="UnenrollOptions__confirmBody">
        <span
          class="UnenrollOptions__confirmIcon"
          :class="`UnenrollOptions__confirmIcon--${props.confirmMode}`"
          v-html="props.confirmMode === 'fullRemoval' ? TRASH_CIRCLE_FILL : CALENDAR_MINUS"
        ></span>
        <span class="UnenrollOptions__confirmTitle">{{ confirmTitle }}</span>
        <span class="UnenrollOptions__confirmDesc">{{ confirmDescription }}</span>
        <div class="UnenrollOptions__confirmActions">
          <button
            type="button"
            class="UnenrollOptions__proceed"
            :class="`UnenrollOptions__proceed--${props.confirmMode}`"
            @click="emit('proceed')"
          >
            Yes, proceed
          </button>
          <button type="button" class="UnenrollOptions__quiet" @click="emit('back')">
            Go back
          </button>
        </div>
      </div>
    </template>

    <!-- Options -->
    <template v-else>
      <div class="UnenrollOptions__dragSpacer"></div>
      <div class="UnenrollOptions__titleBar">
        <button type="button" class="UnenrollOptions__iconBtn" @click="emit('dismiss')">
          <span v-html="XMARK"></span>
        </button>
        <span class="UnenrollOptions__title">Unenroll</span>
      </div>

      <div class="UnenrollOptions__scroll">
        <div class="UnenrollOptions__programHeader">
          <span class="UnenrollOptions__programImage">
            <img
              v-if="props.programImageUrl"
              :src="props.programImageUrl"
              :alt="props.programName"
            />
            <span v-else class="UnenrollOptions__programFallback" v-html="BOOK_FILL"></span>
          </span>
          <span class="UnenrollOptions__programName">{{ props.programName }}</span>
        </div>

        <span class="UnenrollOptions__lessonCount"
          >{{ props.totalLessons }} scheduled lessons</span
        >

        <div
          class="UnenrollOptions__banner"
          :class="
            props.canFullyUnenroll
              ? 'UnenrollOptions__banner--success'
              : 'UnenrollOptions__banner--warning'
          "
        >
          <span
            class="UnenrollOptions__bannerIcon"
            v-html="props.canFullyUnenroll ? CHECK_CIRCLE_FILL : WARNING_FILL"
          ></span>
          <span class="UnenrollOptions__bannerText">{{ bannerText }}</span>
        </div>

        <template v-if="props.canFullyUnenroll">
          <button
            type="button"
            class="UnenrollOptions__optionCard"
            @click="emit('selectFullRemoval')"
          >
            <span
              class="UnenrollOptions__optionIcon UnenrollOptions__optionIcon--destructive"
              v-html="TRASH"
            ></span>
            <span class="UnenrollOptions__optionBody">
              <span
                class="UnenrollOptions__optionTitle UnenrollOptions__optionTitle--destructive"
                >Remove Enrollment</span
              >
              <span class="UnenrollOptions__optionDesc">{{ fullRemovalDesc }}</span>
            </span>
            <span class="UnenrollOptions__optionChevron" v-html="CHEVRON_RIGHT"></span>
          </button>
        </template>

        <template v-else>
          <button
            type="button"
            class="UnenrollOptions__optionCard"
            @click="emit('selectCancelFuture')"
          >
            <span class="UnenrollOptions__optionIcon" v-html="CALENDAR_MINUS"></span>
            <span class="UnenrollOptions__optionBody">
              <span class="UnenrollOptions__optionTitle">Cancel Future Lessons</span>
              <span class="UnenrollOptions__optionDesc">{{ cancelFutureDesc }}</span>
            </span>
            <span class="UnenrollOptions__optionChevron" v-html="CHEVRON_RIGHT"></span>
          </button>

          <div class="UnenrollOptions__disabledCard">
            <span class="UnenrollOptions__disabledHead">
              <span class="UnenrollOptions__disabledIcon" v-html="TRASH"></span>
              <span class="UnenrollOptions__disabledTitle">Remove Enrollment</span>
            </span>
            <span class="UnenrollOptions__disabledText"
              >Full removal is not available — {{ props.lessonsWithData }} lessons contain
              member data.</span
            >
          </div>
        </template>

        <button type="button" class="UnenrollOptions__quiet" @click="emit('dismiss')">
          Never mind
        </button>
        <div class="UnenrollOptions__bottomSpacer"></div>
      </div>
    </template>
  </div>
</template>
