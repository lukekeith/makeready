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
import calendarBottomBar from './CalendarBottomBar.mjs';
import calendarDayCell from './CalendarDayCell.mjs';
import calendarEventListContent from './CalendarEventListContent.mjs';

export const adapters = {
  'group-home': groupHome,
  'card-study': cardStudy,
  GroupCard: groupCard,
  // iPhone-first card comparisons (no Vue twin yet) — generic passthrough to the
  // matching component.<View> case in ViewRegistry.swift.
  CardEvent: cardEvent,
  CardEventMini: cardEventMini,
  CardVideo: iphoneCard('component.CardVideo'),
  CardVideoMini: iphoneCard('component.CardVideoMini'),
  CardStudyMini: iphoneCard('component.CardStudyMini'),
  CardStudySelectable: iphoneCard('component.CardStudySelectable'),
  CardMember: iphoneCard('component.CardMember'),
  CardContact: iphoneCard('component.CardContact'),
  CardActivityType: cardActivityType,
  CardActivity: cardActivity,
  CardLessonActivity: cardLessonActivity,
  CardLesson: cardLesson,
  ScheduledLessonCard: iphoneCard('component.ScheduledLessonCard'),
  CardEnrolled: cardEnrolled,
  CardProgramFull: iphoneCard('component.CardProgramFull'),
  UpcomingLessonCard: iphoneCard('component.UpcomingLessonCard'),
  EnrollmentCard: iphoneCard('component.EnrollmentCard'),
  CardMediaFull: iphoneCard('component.CardMediaFull'),
  CardSearchResult: iphoneCard('component.CardSearchResult'),
  CardBibleSearchResult: cardBibleSearchResult,
  CalendarBottomBar: calendarBottomBar,
  CalendarDayCell: calendarDayCell,
  CalendarEventListContent: calendarEventListContent,
  GroupPostCard: iphoneCard('component.GroupPostCard'),
  // Connected components — seed app state rather than a plain prop bag.
  BlockStyleEditor: blockStyleEditor,
  UserMenu: userMenu,
  // Two-sided twin (Vue + iPhone).
  ActionButton: actionButton,
  BoxButton: boxButton,
  AgeRangeInput: ageRangeInput,
  BackgroundSourceMenu: backgroundSourceMenu,
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
  'CoverImagePicker', 'DatePickerField', 'DialogOverlay', 'DonutChart',
  'ErrorBanner', 'ExegesisVerseView', 'FieldGroup', 'FilterChipDropdown',
  'FullScreenImageViewer', 'GroupActionButton', 'GroupSelectorSheet', 'HamburgerMenu',
  'HeatMapChart', 'HorizontalBarChart', 'InfoPanel', 'InlineFontSizePicker',
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
