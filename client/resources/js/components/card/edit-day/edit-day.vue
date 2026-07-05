<script setup lang="ts">
import PageTitle from '../page-title/page-title.vue'
import TextInput from '../text-input/text-input.vue'
import CardLessonActivity from '../card-lesson-activity/card-lesson-activity.vue'
import BoxButton from '../box-button/box-button.vue'

// EditDay — CAPTURE-ONLY web twin of the iPhone lesson editor
// (Pages/Manage/Program/EditDay.swift `dayContent`, creator chrome). The
// production surface is islands/leader-app/components/edit-day-pane.vue
// (SlideStack + swipe + drag interactions); this twin mirrors its STATIC
// layout from the same leaf twins so the compare tool can pin comments —
// like GroupHomeLeader. Parity fixes found here must land in the pane too.
//
// Layout (iOS VStack spacing 0):
//   • PageTitle.iconTitleLink — chevron.left / "Day N" / Done
//   • FieldGroup { TextInput floating "Lesson title" } — H16, top 8
//   • ScrollView VStack(spacing 4) padded H16 top 16:
//       CardLessonActivity(size small) per activity (adapter pre-computes
//       the iOS title/description/status mapping from EditDay.swift),
//       12px spacer, add BoxButton (icon-only plus, creator only),
//       Preview BoxButton, 32px bottom pad.

export interface EditDayCard {
  id: string
  /** Raw ActivityType (READ / USER_INPUT / EXEGESIS / VIDEO / YOUTUBE). */
  type: string
  title: string
  description?: string
  /** 'confirmed' (configured) | 'new' (not ready — brand border). */
  status: string
  estimatedMinutes?: number
  /** Icon override (EditDay's VIDEO card uses 'play', per iOS). */
  iconKey?: string
}

interface Props {
  day?: number
  lessonTitle?: string
  activities?: EditDayCard[]
  /** Creator chrome (add button). Captures render the creator state. */
  canEdit?: boolean
  // Capture-only: render the iOS device status bar (the iPhone reference
  // includes the simulator's). Production never passes this.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  day: 1,
  lessonTitle: '',
  activities: () => [],
  canEdit: true,
  statusBar: false,
})

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
</script>

<template>
  <div :class="['EditDay', props.class]">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="EditDay__statusbar" aria-hidden="true">
      <span class="EditDay__clock">9:41</span>
      <span class="EditDay__indicators">
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" />
          <rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" />
        </svg>
        <svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor">
          <path d="M8.5 2C5.6 2 3 3.1 1 4.9l1.4 1.5C4 4.9 6.1 4 8.5 4s4.5.9 6.1 2.4L16 4.9C14 3.1 11.4 2 8.5 2z" />
          <path d="M8.5 6.2c-1.6 0-3 .6-4.1 1.6l1.5 1.5c.7-.6 1.6-1 2.6-1s1.9.4 2.6 1l1.5-1.5C11.5 6.8 10.1 6.2 8.5 6.2z" />
          <circle cx="8.5" cy="11" r="1.3" />
        </svg>
        <svg width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="currentColor" stroke-opacity="0.4" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4z" fill="currentColor" fill-opacity="0.4" />
        </svg>
      </span>
    </div>

    <PageTitle
      :title="`Day ${props.day}`"
      :left-icon="BACK_CHEVRON"
      right-link="Done"
    />

    <div class="EditDay__titleField">
      <div class="FieldGroup">
        <TextInput floating-label="Lesson title" :text="props.lessonTitle" />
      </div>
    </div>

    <div class="EditDay__scroll">
      <div class="EditDay__activities">
        <CardLessonActivity
          v-for="a in props.activities"
          :key="a.id"
          size="small"
          :type="a.type"
          :title="a.title"
          :description="a.description"
          :status="a.status"
          :estimated-minutes="a.estimatedMinutes"
          :icon-key="a.iconKey"
        />
      </div>

      <div v-if="props.canEdit" class="EditDay__addSpacer"></div>
      <BoxButton
        v-if="props.canEdit"
        variant="secondary"
        size="lg"
        :icon="PLUS"
        icon-position="right"
        full-width
        :icon-opacity="0.5"
      />

      <BoxButton
        class="EditDay__previewBtn"
        label="Preview"
        :icon="EYE"
        icon-position="right"
        variant="secondary"
        size="lg"
        full-width
        :icon-opacity="0.5"
      />
    </div>
  </div>
</template>
