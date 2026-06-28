/**
 * Adapter registry.
 *
 * Each comparison declares an `adapter` key (defaults to its `id`). The adapter
 * projects the comparison's canonical `shared` block into the two platform
 * fixture shapes via `toClient(shared)` and `toIphone(shared)`.
 *
 * To add a new comparison: write `<id>.mjs` exporting { toClient, toIphone },
 * register it here, then drop a `fixtures/compare/<group>/<id>.json` spec.
 */
import groupHome from './group-home.mjs';
import cardStudy from './card-study.mjs';
import groupCard from './GroupCard.mjs';
import cardLesson from './CardLesson.mjs';
import cardEventMini from './CardEventMini.mjs';
import cardLessonActivity from './CardLessonActivity.mjs';
import cardEvent from './CardEvent.mjs';
import cardEnrolled from './CardEnrolled.mjs';
import enrollmentCard from './EnrollmentCard.mjs';
import { iphoneCard } from './iphone-card.mjs';
import blockStyleEditor from './BlockStyleEditor.mjs';
import userMenu from './UserMenu.mjs';
import actionButton from './ActionButton.mjs';
import boxButton from './BoxButton.mjs';
import ageRangeInput from './AgeRangeInput.mjs';
import backgroundSourceMenu from './BackgroundSourceMenu.mjs';
import cardActivityType from './CardActivityType.mjs';
import cardActivity from './CardActivity.mjs';
import cardBibleSearchResult from './CardBibleSearchResult.mjs';
import cardContact from './CardContact.mjs';
import cardMember from './CardMember.mjs';
import calendarBottomBar from './CalendarBottomBar.mjs';
import calendarDayCell from './CalendarDayCell.mjs';
import calendarEventListContent from './CalendarEventListContent.mjs';
import calendarWeekdayHeader from './CalendarWeekdayHeader.mjs';
import cardGroupMini from './CardGroupMini.mjs';
import cardMediaFull from './CardMediaFull.mjs';
import cardProgramFull from './CardProgramFull.mjs';
import cardSearchResult from './CardSearchResult.mjs';
import cardStudyMini from './CardStudyMini.mjs';
import cardStudySelectable from './CardStudySelectable.mjs';
import cardVideo from './CardVideo.mjs';
import cardVideoMini from './CardVideoMini.mjs';
import groupPostCard from './GroupPostCard.mjs';
import scheduledLessonCard from './ScheduledLessonCard.mjs';
import skeletonCardGroup from './SkeletonCardGroup.mjs';
import skeletonCardLesson from './SkeletonCardLesson.mjs';
import skeletonCardLessonActivity from './SkeletonCardLessonActivity.mjs';
import skeletonCardMediaFull from './SkeletonCardMediaFull.mjs';
import skeletonCardProgramFull from './SkeletonCardProgramFull.mjs';
import skeletonCardStudy from './SkeletonCardStudy.mjs';
import slideButton from './SlideButton.mjs';
import swipeableCard from './SwipeableCard.mjs';
import upcomingLessonCard from './UpcomingLessonCard.mjs';
import donutChart from './DonutChart.mjs';
import heatMapChart from './HeatMapChart.mjs';
import horizontalBarChart from './HorizontalBarChart.mjs';

export const adapters = {
  'group-home': groupHome,
  'card-study': cardStudy,
  GroupCard: groupCard,
  // iPhone-first card comparisons (no Vue twin yet) — generic passthrough to the
  // matching component.<View> case in ViewRegistry.swift.
  CardEvent: cardEvent,
  CardEventMini: cardEventMini,
  CardVideo: cardVideo,
  CardVideoMini: cardVideoMini,
  CardStudyMini: cardStudyMini,
  CardStudySelectable: cardStudySelectable,
  CardMember: cardMember,
  CardContact: cardContact,
  CardActivityType: cardActivityType,
  CardActivity: cardActivity,
  CardLessonActivity: cardLessonActivity,
  CardLesson: cardLesson,
  ScheduledLessonCard: scheduledLessonCard,
  CardEnrolled: cardEnrolled,
  CardProgramFull: cardProgramFull,
  UpcomingLessonCard: upcomingLessonCard,
  EnrollmentCard: enrollmentCard,
  CardMediaFull: cardMediaFull,
  CardSearchResult: cardSearchResult,
  CardBibleSearchResult: cardBibleSearchResult,
  CalendarBottomBar: calendarBottomBar,
  CalendarDayCell: calendarDayCell,
  CalendarEventListContent: calendarEventListContent,
  CalendarWeekdayHeader: calendarWeekdayHeader,
  CardGroupMini: cardGroupMini,
  GroupPostCard: groupPostCard,
  SkeletonCardGroup: skeletonCardGroup,
  SkeletonCardLesson: skeletonCardLesson,
  SkeletonCardLessonActivity: skeletonCardLessonActivity,
  SkeletonCardMediaFull: skeletonCardMediaFull,
  SkeletonCardProgramFull: skeletonCardProgramFull,
  SkeletonCardStudy: skeletonCardStudy,
  // Connected components — seed app state rather than a plain prop bag.
  BlockStyleEditor: blockStyleEditor,
  UserMenu: userMenu,
  // Two-sided twin (Vue + iPhone).
  ActionButton: actionButton,
  SlideButton: slideButton,
  SwipeableCard: swipeableCard,
  BoxButton: boxButton,
  AgeRangeInput: ageRangeInput,
  BackgroundSourceMenu: backgroundSourceMenu,
  DonutChart: donutChart,
  HeatMapChart: heatMapChart,
  HorizontalBarChart: horizontalBarChart,
};

// iPhone-first component comparisons scaffolded from the full Components/ inventory
// (organized by their iOS folder → fixture `group`). Each maps generically to a
// `component.<id>` ViewRegistry.swift case to be added when that component is first
// captured. As a Vue twin lands, promote the entry to a real two-sided adapter above
// (see card-study.mjs / GroupCard.mjs) — nothing about the fixture changes.
const IPHONE_FIRST_COMPONENTS = [
  'ActionCardMenu', 'AddActivityMenu', 'AddMenu',
  'Alert', 'AlphabetScrubber', 'Avatar',
  'BackgroundSwatch', 'BibleVerseTextLayout', 'BlockStyleEditor',
  'CalendarBottomBar', 'CalendarDayCell', 'CalendarEventListContent',
  'CalendarWeekdayHeader', 'CardGroupMini', 'CardSpinnerOverlay', 'ConfirmationOverlay',
  'CoverImagePicker', 'DatePickerField', 'DialogOverlay',
  'ErrorBanner', 'ExegesisVerseView', 'FieldGroup', 'FilterChipDropdown',
  'FullScreenImageViewer', 'GroupActionButton', 'GroupSelectorSheet', 'HamburgerMenu',
  'InfoPanel', 'InlineFontSizePicker',
  'InviteMenu', 'InviteQRCodeView', 'Kpi', 'LargeTextInput',
  'LessonActionMenu', 'LineChart', 'MarkdownEditor', 'MemberListItem',
  'MenuInput', 'MultilineTextInput', 'NavBar', 'PageHeader',
  'PageTitle', 'RichTextInput', 'SearchField', 'SearchableList',
  'SectionedTableView', 'SelectableLockedBlockView', 'ShareInviteSheet', 'ShimmerView',
  'SkeletonCardGroup', 'SkeletonCardLesson', 'SkeletonCardLessonActivity', 'SkeletonCardMediaFull',
  'SkeletonCardProgramFull', 'SkeletonCardStudy', 'SkeletonEnrollmentCard', 'SkeletonPostCard',
  'SlideButton', 'SplitMonthCalendar', 'StylePickerMenu', 'SwipeableCard',
  'TabSlider', 'TagInput', 'TextInput', 'ThemedContentView',
  'ToggleControl', 'UnenrollConfirmation', 'UserMenu', 'VerticalBarChart',
  'VideoGridItem', 'VideoPreview', 'VideoSourceBar', 'WeekdayIndicator',
];
for (const id of IPHONE_FIRST_COMPONENTS) {
  if (!adapters[id]) adapters[id] = iphoneCard(`component.${id}`);
}

export function getAdapter(key) {
  const adapter = adapters[key];
  if (!adapter) {
    throw new Error(
      `No compare adapter registered for "${key}". Available: ${Object.keys(adapters).join(', ') || '(none)'}`,
    );
  }
  return adapter;
}
