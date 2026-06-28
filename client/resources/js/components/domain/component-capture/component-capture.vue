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
import VerticalBarChart from '../../card/vertical-bar-chart/vertical-bar-chart.vue'
import LineChart from '../../card/line-chart/line-chart.vue'
import ExegesisVerseView from '../../card/exegesis-verse-view/exegesis-verse-view.vue'
import SelectableLockedBlockView from '../../card/selectable-locked-block-view/selectable-locked-block-view.vue'
import Alert from '../../card/alert/alert.vue'
import AlphabetScrubber from '../../card/alphabet-scrubber/alphabet-scrubber.vue'
import Avatar from '../../card/avatar/avatar.vue'
import DialogOverlay from '../../card/dialog-overlay/dialog-overlay.vue'
import FullScreenImageViewer from '../../card/full-screen-image-viewer/full-screen-image-viewer.vue'
import GroupSelectorSheet from '../../card/group-selector-sheet/group-selector-sheet.vue'
import InfoPanel from '../../card/info-panel/info-panel.vue'
import Kpi from '../../card/kpi/kpi.vue'
import MemberListItem from '../../card/member-list-item/member-list-item.vue'
import WeekdayIndicator from '../../card/weekday-indicator/weekday-indicator.vue'
import SkeletonEnrollmentCard from '../../card/skeleton-enrollment-card/skeleton-enrollment-card.vue'
import ConfirmationOverlay from '../../card/confirmation-overlay/confirmation-overlay.vue'
import ErrorBanner from '../../card/error-banner/error-banner.vue'
import UnenrollConfirmation from '../../card/unenroll-confirmation/unenroll-confirmation.vue'
import GroupActionButton from '../../card/group-action-button/group-action-button.vue'
import SkeletonPostCard from '../../card/skeleton-post-card/skeleton-post-card.vue'
import BackgroundSwatch from '../../card/background-swatch/background-swatch.vue'
import BlockStyleEditor from '../../card/block-style-editor/block-style-editor.vue'
import CoverImagePicker from '../../card/cover-image-picker/cover-image-picker.vue'
import DatePickerField from '../../card/date-picker-field/date-picker-field.vue'
import FieldGroup from '../../card/field-group/field-group.vue'
import InlineFontSizePicker from '../../card/inline-font-size-picker/inline-font-size-picker.vue'
import LargeTextInput from '../../card/large-text-input/large-text-input.vue'
import MarkdownEditor from '../../card/markdown-editor/markdown-editor.vue'
import MenuInput from '../../card/menu-input/menu-input.vue'
import MultilineTextInput from '../../card/multiline-text-input/multiline-text-input.vue'
import RichTextInput from '../../card/rich-text-input/rich-text-input.vue'
import SearchField from '../../card/search-field/search-field.vue'
import TagInput from '../../card/tag-input/tag-input.vue'
import TextInput from '../../card/text-input/text-input.vue'
import ToggleControl from '../../card/toggle-control/toggle-control.vue'

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
  // iOS VerticalBarChart (Swift Charts vertical BarMark) — card + bar/axis twin.
  VerticalBarChart,
  // iOS LineChart (Swift Charts LineMark / AreaMark) — inline-SVG line/area twin.
  LineChart,
  // iOS ExegesisVerseView (UITextView scripture view) — justified Charter twin.
  ExegesisVerseView,
  // iOS SelectableLockedBlockView (read-only UITextView locked read block) —
  // justified Charter twin with purple/preview selection runs.
  SelectableLockedBlockView,
  // iOS Alert (Components/Display/Alert.swift) — inline warning/critical banner.
  Alert,
  // iOS AlphabetScrubber (Components/Display/AlphabetScrubber.swift) — vertical
  // A–Z navigation rail; clipped/centered to the harness's 360pt frame.
  AlphabetScrubber,
  // iOS Avatar (Components/Display/Avatar.swift) — circular avatar with six fixed
  // sizes; initials-gradient / person-icon fallback (photo never resolves in the
  // isolated snapshot).
  Avatar,
  // iOS DialogOverlay (Components/Display/DialogOverlay.swift) — centered dialog
  // with optional title/message + vertical button stack. NB: the iPhone
  // reference is empty (entrance animation gates `visible`); this twin renders
  // the dialog at its final visible state.
  DialogOverlay,
  // iOS FullScreenImageViewer (Components/Display/FullScreenImageViewer.swift) —
  // full-bleed black image canvas + top-right close button. NB: the iPhone
  // reference is a pure-black canvas (its `photo.fill` placeholder renders
  // black-on-black); the adapter omits the imageURL so this twin matches.
  FullScreenImageViewer,
  // iOS GroupSelectorSheet (Components/Display/GroupSelectorSheet.swift) — sheet
  // picker (inline nav title + selectable group rows). NB: the iPhone component
  // is self-contained (internal GroupFixtureManager hardcodes the list) and the
  // ViewRegistry forces `selectedGroup: .constant(nil)`, so both fixture
  // variants render the same hardcoded list with no selection / no close button;
  // the adapter feeds that exact data to match. The twin stays data-driven.
  GroupSelectorSheet,
  // iOS InfoPanel (Components/Display/InfoPanel.swift) — rounded label/value
  // panel in keyValue (label left / value right) or data (stacked) mode. NB:
  // the iOS `.ultraThinMaterial` background renders invisible in the isolated
  // snapshot, so this twin's panel background is transparent (dividers + text
  // only) to match.
  InfoPanel,
  // iOS Kpi (Components/Display/Kpi.swift) — KPI card with four layout variants
  // (standard / compact / sparkline / iconValue) on a white@5% rounded card.
  // The sparkline reproduces Swift Charts' monotone LineMark + AreaMark; SF
  // symbols map to inline SVG and the iconValue tint colors (.blue/.green) map
  // to the iOS dark-mode system hexes in the adapter.
  Kpi,
  // iOS MemberListItem (Components/Display/MemberListItem.swift) — full-width
  // member/contact list row: gray initials avatar + name + demographics/group
  // chips + optional trailing purple Invite pill (four variants).
  MemberListItem,
  // iOS WeekdayIndicator (Components/Display/WeekdayIndicator.swift) — Sunday-first
  // row of 7 weekday letters (S M T W T F S), each with a dot beneath: enabled =
  // white letter + brand-purple dot, disabled = white@30% letter + no dot.
  WeekdayIndicator,
  // iOS SkeletonEnrollmentCard (Components/Domain/SkeletonEnrollmentCard.swift) —
  // loading enrollment card: 64×64 book.fill cover placeholder + program name +
  // "<n> days" + a brand spoke spinner with "Creating…". Full-width row card.
  SkeletonEnrollmentCard,
  // iOS ConfirmationOverlay (Components/Feedback/ConfirmationOverlay.swift) — a
  // centered card with an animated completion circle (style icon), a message,
  // and an action button. NB: the iPhone reference is BLANK (entrance animation
  // gates contentOpacity); this twin renders the overlay at its final visible
  // state. Processing variant shows a spinning ring + muted button.
  ConfirmationOverlay,
  // iOS ErrorBanner (Components/Feedback/ErrorBanner.swift) — top error banner:
  // a red rounded bar with a warning triangle, a message (lineLimit 2), and an
  // optional white@20% Retry pill (arrow.clockwise + "Retry").
  ErrorBanner,
  // iOS UnenrollConfirmation (Components/Feedback/UnenrollConfirmation.swift) —
  // a namespace that presents a ConfirmationOverlay (style .warning, "Done"
  // button) whose message is derived from the unenroll option. This twin renders
  // that resulting overlay (warning circle + message + Done button). NB: the
  // iPhone reference is BLANK (entrance animation gates contentOpacity); this twin
  // renders the overlay at its final visible state.
  UnenrollConfirmation,
  // iOS GroupActionButton (Components/Group/GroupActionButton.swift) — pill with
  // a white label on the left and a brand-purple SF-symbol icon on the right, in
  // a white@10% capsule (Video / Message / Meeting / Gallery).
  GroupActionButton,
  // iOS SkeletonPostCard (Components/Group/SkeletonPostCard.swift) — loading
  // post card: shimmer author row, a "<program> starts soon!" title (or shimmer
  // bar) + two shimmer text lines, a 180-tall cover shimmer with a white spoke
  // spinner, and an eye/share action bar. Full-width, no card background.
  SkeletonPostCard,
  // iOS BackgroundSwatch (Components/Input/BackgroundSwatch.swift) — 40×40 rounded
  // swatch: appBackground base + optional translucent color overlay. In the
  // isolated snapshot the iOS AsyncImage never resolves, so image variants show
  // the appBackground fallback; the adapter omits the URL and forwards `hasImage`.
  BackgroundSwatch,
  // iOS BlockStyleEditor (Components/Input/BlockStyleEditor.swift) — inline read-block
  // style editor card: optional title + optional theme picker (FieldGroup/MenuInput
  // showing "No Theme"), an image well (photo.on.rectangle placeholder, or empty when
  // an image is configured since the iOS AsyncImage never resolves in the snapshot)
  // beside a color well (solid hex, or a toggle-circle placeholder), and a 5-tile
  // "Aa" font-size picker with a white border on the selected size.
  BlockStyleEditor,
  // iOS CoverImagePicker (Components/Input/CoverImagePicker.swift) — 240px cover
  // well: translucent placeholder (white@0.1 when an image is configured since the
  // iOS AsyncImage never resolves in the snapshot, white@0.2 empty) + bottom
  // appBackground gradient + bottom-left program name/description (or an "Add cover
  // image"/"Add program name" placeholder), plus a top-right pencil in display mode.
  CoverImagePicker,
  // iOS DatePickerField (Components/Input/DatePickerField.swift) — a field-group
  // row: label on the left + two trailing white@10% pills (date / time). The
  // adapter pre-formats the date/time in local tz to match the iOS
  // DateFormatters (monthPaddedDayYear "Jan 30, 2026" + shortTime "03:41").
  DatePickerField,
  // iOS FieldGroup (Components/Input/FieldGroup.swift) — rounded white@5% container
  // grouping value rows separated by hairline white@10% dividers, with an optional
  // trailing white@70% description row. Rows render s17 white with 16px padding;
  // the description renders s13 with 16/12 padding.
  FieldGroup,
  // iOS InlineFontSizePicker (Components/Input/InlineFontSizePicker.swift) — a
  // horizontal row of 5 "Aa" tiles (xs/s/m/lg/xl), spacing 4. Each tile fills the
  // width equally, is 60pt tall, white@5% bg + 4px radius, "Aa" semibold white at
  // a per-key point size (13/16/19/23/27); the selected key's tile gets a 2px
  // white border.
  InlineFontSizePicker,
  // iOS LargeTextInput (Components/Input/LargeTextInput.swift) — a large single
  // field: muted s12 label, a tall s28 text row with an optional leading
  // (currency $) or trailing (phone/email/percentage) s20 icon, and a hairline
  // white@20% bottom border. Wrapped by the harness in a FieldGroup card.
  LargeTextInput,
  // iOS MarkdownEditor (Components/Input/MarkdownEditor.swift) — markdown editor
  // card: a fixed formatting toolbar (H▾ | list · quote | bold · italic | Aa |
  // undo · redo) over a backgroundDark editor area. NB: in the isolated snapshot
  // the iOS HTML→AttributedString conversion strips markdown markers but renders
  // every block as flat 17pt white body text (no heading/bold/italic/list/quote
  // styling), preserving blank-line gaps; this twin renders the markdown
  // line-by-line with markers stripped to mirror that.
  MarkdownEditor,
  // iOS MenuInput (Components/Input/MenuInput.swift) — labelled picker input in a
  // FieldGroup card. The snapshot shows each style's resting render: menu / wheel /
  // inline are an identical collapsed row (label · selectedOption · chevron.down);
  // segmented is an uppercase label over a white@10% capsule track whose selected
  // segment is bold (its material pill is invisible in the isolated snapshot).
  MenuInput,
  // iOS MultilineTextInput (Components/Input/MultilineTextInput.swift) — a tall
  // FieldGroup-wrapped description field with a floating placeholder label that
  // rests inline when empty and floats up small when filled.
  MultilineTextInput,
  // iOS RichTextInput (Components/Input/RichTextInput.swift) — a rich-text editor
  // card: a fixed toolbar (bold · italic · underline | AA▾ heading | undo · redo)
  // over a backgroundDark editor area. NB: in the isolated snapshot the iOS
  // TextEditor's `.font(s17)` flattens the HTML→AttributedString — `<h1>`/`<p>`
  // blocks split into lines but render as flat 17pt white body text (no heading/
  // bold/italic styling); this twin parses block tags into lines and strips the
  // rest to mirror that.
  RichTextInput,
  // iOS SearchField (Components/Input/SearchField.swift) — animated search input.
  // The snapshot shows each variant's resting state: Inactive is a borderless field
  // (magnifyingglass + placeholder, white@50, no close button); active states add a
  // white@20% 1px border and a trailing 42×42 close button (xmark). The field/button
  // .ultraThinMaterial fills render invisible in isolation, so the twin draws them
  // transparent (border only). Filled text is solid white; placeholder is white@50.
  SearchField,
  // iOS TagInput (Components/Input/TagInput.swift) — tag-entry field: a white@5%
  // rounded well of flow-wrapped removable brand-purple tag pills (s12Semibold
  // label + white@70 xmark) above an inline text field that, in the captured
  // variants, only shows its "Add tag..." placeholder in tertiary-label gray.
  TagInput,
  // iOS TextInput (Components/Input/TextInput.swift) — single-line text input in a
  // FieldGroup card, three styles: placeholder (prompt white@50 / value white,
  // left-aligned), labeled (brand-purple leading icon + s17 white@70 label + a
  // trailing white@70 value), and floating (a placeholder/label that rests inline
  // when empty and floats up small, offset y -18, when filled).
  TextInput,
  // iOS ToggleControl (Components/Input/ToggleControl.swift) — a settings row
  // (title s17 white + description s13 white@50 on the left, a custom 63×28 pill
  // toggle on the right) wrapped by the harness in a ToggleGroup (white@10%
  // rounded-10 card). Track is white (on) / white@50 (off) with a 33×21
  // appBackground knob that aligns trailing (on) / leading (off).
  ToggleControl,
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
