<script setup lang="ts">
// Capture-only island: renders a single design-system component by name with
// arbitrary props, so the Compare tool can screenshot it in isolation against
// the same data the iPhone app uses. Add components to the registry below as
// new component comparisons are introduced.
import { computed } from 'vue'
import CardStudy from '../../card/card-study/card-study.vue'
import CardGroup from '../../card/card-group/card-group.vue'
import CardGroupMini from '../../card/card-group-mini/card-group-mini.vue'
import CardEnrolled from '../../card/card-enrolled/card-enrolled.vue'
import CardLesson from '../../card/card-lesson/card-lesson.vue'
import CardEventMini from '../../card/card-event-mini/card-event-mini.vue'
import CardLessonActivity from '../../card/card-lesson-activity/card-lesson-activity.vue'
import CardEvent from '../../card/card-event/card-event.vue'
import ActionButton from '../../card/action-button/action-button.vue'
import BoxButton from '../../card/box-button/box-button.vue'
import AgeRangeInput from '../../card/age-range-input/age-range-input.vue'
import BackgroundSourceMenu from '../../card/background-source-menu/background-source-menu.vue'
import CardActivityType from '../../card/card-activity-type/card-activity-type.vue'
import CardActivity from '../../card/card-activity/card-activity.vue'
import CardBibleSearchResult from '../../card/card-bible-search-result/card-bible-search-result.vue'
import CardContact from '../../card/card-contact/card-contact.vue'
import CardMember from '../../card/card-member/card-member.vue'
import CardMediaFull from '../../card/card-media-full/card-media-full.vue'
import CalendarBottomBar from '../../card/calendar-bottom-bar/calendar-bottom-bar.vue'
import CalendarDayCell from '../../card/calendar-day-cell/calendar-day-cell.vue'
import CalendarEventListContent from '../../card/calendar-event-list-content/calendar-event-list-content.vue'
import CalendarWeekdayHeader from '../../card/calendar-weekday-header/calendar-weekday-header.vue'

const props = defineProps<{
  component: string
  props?: Record<string, unknown>
}>()

const registry: Record<string, unknown> = {
  CardStudy,
  CardGroup,
  CardGroupMini,
  CardEnrolled,
  CardLesson,
  CardEventMini,
  CardLessonActivity,
  CardEvent,
  ActionButton,
  BoxButton,
  AgeRangeInput,
  BackgroundSourceMenu,
  CardActivityType,
  CardActivity,
  CardBibleSearchResult,
  CardContact,
  CardMember,
  CardMediaFull,
  CalendarBottomBar,
  CalendarDayCell,
  CalendarEventListContent,
  CalendarWeekdayHeader,
}

const Resolved = computed(() => registry[props.component] ?? null)
</script>

<template>
  <!-- Center the rendered component horizontally so fixed-width tiles (e.g.
       120px Mini cards) sit centered in the capture frame like the iPhone
       sizeThatFits snapshot. Full-width Row cards still fill (width:100%). -->
  <div style="display: flex; justify-content: center; align-items: flex-start; width: 100%">
    <component :is="Resolved" v-if="Resolved" v-bind="props.props" />
    <div v-else style="color: #f87171; font-family: monospace; padding: 16px">
      Unknown capture component: "{{ component }}"
    </div>
  </div>
</template>
