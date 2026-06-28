<script setup lang="ts">
// Capture-only island: renders a single design-system component by name with
// arbitrary props, so the Compare tool can screenshot it in isolation against
// the same data the iPhone app uses. Add components to the registry below as
// new component comparisons are introduced.
import { computed } from 'vue'
import CardStudy from '../../card/card-study/card-study.vue'
import CardGroup from '../../card/card-group/card-group.vue'
import CardGroupMini from '../../card/card-group-mini/card-group-mini.vue'
import CardStudyMini from '../../card/card-study-mini/card-study-mini.vue'
import CardStudySelectable from '../../card/card-study-selectable/card-study-selectable.vue'
import CardEnrolled from '../../card/card-enrolled/card-enrolled.vue'
import EnrollmentCard from '../../card/enrollment-card/enrollment-card.vue'
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
import CardProgramFull from '../../card/card-program-full/card-program-full.vue'
import CardSearchResult from '../../card/card-search-result/card-search-result.vue'
import CardVideo from '../../card/card-video/card-video.vue'
import CardVideoMini from '../../card/card-video-mini/card-video-mini.vue'
import GroupPostCard from '../../card/group-post-card/group-post-card.vue'
import ScheduledLessonCard from '../../card/scheduled-lesson-card/scheduled-lesson-card.vue'
import UpcomingLessonCard from '../../card/upcoming-lesson-card/upcoming-lesson-card.vue'
import SkeletonCardGroup from '../../card/skeleton-card-group/skeleton-card-group.vue'
import SkeletonCardLesson from '../../card/skeleton-card-lesson/skeleton-card-lesson.vue'
import SkeletonCardLessonActivity from '../../card/skeleton-card-lesson-activity/skeleton-card-lesson-activity.vue'
import SkeletonCardMediaFull from '../../card/skeleton-card-media-full/skeleton-card-media-full.vue'
import SkeletonCardProgramFull from '../../card/skeleton-card-program-full/skeleton-card-program-full.vue'
import SkeletonCardStudy from '../../card/skeleton-card-study/skeleton-card-study.vue'
import CardSlideButton from '../../card/card-slide-button/card-slide-button.vue'
import SwipeableCard from '../../card/swipeable-card/swipeable-card.vue'
import DonutChart from '../../card/donut-chart/donut-chart.vue'
import HeatMapChart from '../../card/heat-map-chart/heat-map-chart.vue'
import HorizontalBarChart from '../../card/horizontal-bar-chart/horizontal-bar-chart.vue'

const props = defineProps<{
  component: string
  props?: Record<string, unknown>
}>()

const registry: Record<string, unknown> = {
  CardStudy,
  CardGroup,
  CardGroupMini,
  CardStudyMini,
  CardStudySelectable,
  CardEnrolled,
  EnrollmentCard,
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
  CardProgramFull,
  CardSearchResult,
  CardVideo,
  CardVideoMini,
  GroupPostCard,
  ScheduledLessonCard,
  UpcomingLessonCard,
  SkeletonCardGroup,
  SkeletonCardLesson,
  SkeletonCardLessonActivity,
  SkeletonCardMediaFull,
  SkeletonCardProgramFull,
  SkeletonCardStudy,
  // iOS SwipeableCard reveal action (circular icon button). Registered under the
  // `SlideButton` comparison id; the component itself is `CardSlideButton` to
  // avoid colliding with the labeled rectangular `SlideButton` component.
  SlideButton: CardSlideButton,
  // iOS SwipeableCard at rest — renders only its content card (CardGroupMini);
  // the slide buttons stay hidden behind it until swiped.
  SwipeableCard,
  // iOS DonutChart (Swift Charts SectorMark) — inline-SVG donut/pie twin.
  DonutChart,
  // iOS HeatMapChart (Swift Charts RectangleMark grid) — CSS-grid heatmap twin.
  HeatMapChart,
  // iOS HorizontalBarChart (Swift Charts horizontal BarMark) — bar/axis twin.
  HorizontalBarChart,
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
