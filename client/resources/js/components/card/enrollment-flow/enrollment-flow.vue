<script setup lang="ts">
// EnrollmentFlow — web twin of the iPhone EnrollmentFlowModal
// (Pages/Manage/Group/Enrollment/EnrollmentFlowModal.swift): the 3-panel
// enrollment wizard presented as the `.enrollmentFlow` /
// `.programEnrollmentFlow` modal (dismissOnTapOutside FALSE).
//
// iOS mounts a GeometryReader HStack of exactly 3 full-width panels offset by
// `-panelIndex * width` (Motion.standard 300ms ease-in-out):
//   panel 0 — SelectGroupPage (program entry) OR SelectStudyProgramPage
//             (group entry); exactly one exists per flow
//   panel 1 — SelectEnrollDatePage (EnrollCalendar + frosted range panel +
//             DayOfWeekPicker)
//   panel 2 — ConfirmEnrollmentPage(.create)
//
// Fully controlled: the production host owns step/selection/toggle state and
// binds the emits; compare captures pass static props and bind nothing.
// The modal chrome (sheet, scrim, drag capsule) is supplied by managed-modal
// in production; the twin renders the content incl. the 16px drag-indicator
// spacer above each PageTitle (iOS modalProvidesDragIndicator).
import { computed } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import SearchField from '../search-field/search-field.vue'
import CardGroup from '../card-group/card-group.vue'
import CardStudySelectable from '../card-study-selectable/card-study-selectable.vue'
import SkeletonCardGroup from '../skeleton-card-group/skeleton-card-group.vue'
import SkeletonCardStudy from '../skeleton-card-study/skeleton-card-study.vue'
import ToggleControl from '../toggle-control/toggle-control.vue'
import MenuInput from '../menu-input/menu-input.vue'
import EnrollCalendar from '../enroll-calendar/enroll-calendar.vue'

export interface EnrollmentFlowGroupRow {
  id: string
  name: string
  description?: string
  memberCount: number
  enrollmentCount?: number
  imageUrl?: string
  enrolled?: boolean // already actively enrolled in the program → dimmed
}

export interface EnrollmentFlowProgramRow {
  id: string
  name: string
  description?: string
  days: number
  imageUrl?: string
  isPublished?: boolean
  enrolledUntil?: string // "enrolled until Jun 30" (brand line)
  disabled?: boolean // currently enrolled OR enrollment data still loading
}

interface Props {
  /** 'group' = opened from a group (pick a PROGRAM first); 'program' =
   *  opened from a program (pick a GROUP first). */
  entry?: 'group' | 'program'
  /** Panel index 0/1/2 (iOS panelIndex). */
  step?: number
  groups?: EnrollmentFlowGroupRow[]
  programs?: EnrollmentFlowProgramRow[]
  listLoading?: boolean
  listError?: string
  selectedGroupId?: string | null
  selectedProgramId?: string | null
  searchText?: string
  // ── Dates panel (passed through to EnrollCalendar) ──
  calendarStartMonth?: string
  calendarMonthCount?: number
  calendarToday?: string
  startDate?: string | null
  endDate?: string | null
  enabledDays?: number[]
  overriddenDates?: string[]
  existingLessonDates?: string[]
  // ── Confirm panel ──
  confirmGroup?: {
    name: string
    description?: string
    isPrivate?: boolean
    memberCount: number
    imageUrl?: string
  } | null
  confirmProgram?: {
    name: string
    description?: string
    days: number
    imageUrl?: string
  } | null
  /** "HH:mm" 24h (iOS default 07:30). */
  smsTime?: string
  requireResponse?: boolean
  syncToStudy?: boolean
  syncMode?: 'Automatic' | 'Approval'
  /** Production: render a native time input over the Send-invites value. */
  interactive?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  entry: 'group',
  step: 0,
  groups: () => [],
  programs: () => [],
  listLoading: false,
  listError: '',
  selectedGroupId: null,
  selectedProgramId: null,
  searchText: '',
  calendarStartMonth: '',
  calendarMonthCount: 12,
  calendarToday: '',
  startDate: null,
  endDate: null,
  enabledDays: () => [1, 2, 3, 4, 5],
  overriddenDates: () => [],
  existingLessonDates: () => [],
  confirmGroup: null,
  confirmProgram: null,
  smsTime: '07:30',
  requireResponse: true,
  syncToStudy: false,
  syncMode: 'Automatic',
  interactive: false,
})

const emit = defineEmits<{
  close: []
  back: []
  next: []
  confirm: []
  retry: []
  selectGroup: [id: string]
  selectProgram: [id: string]
  tapDraftProgram: [id: string]
  'update:searchText': [value: string]
  selectDate: [key: string]
  longpressDate: [key: string]
  toggleWeekday: [weekday: number]
  'update:requireResponse': [value: boolean]
  'update:syncToStudy': [value: boolean]
  'update:syncMode': [value: 'Automatic' | 'Approval']
  'update:smsTime': [value: string]
}>()

// ── Icons (SF Symbols) ──
const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3.5 3.5l13 13M16.5 3.5l-13 13"/></svg>'
const CHEVRON_LEFT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 5l-7 7 7 7"/></svg>'
const MAGNIFYING_GLASS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><circle cx="10.5" cy="10.5" r="7"/><path d="M15.8 15.8L21 21"/></svg>'
const WARNING_TRIANGLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3L1.8 20.5h20.4L12 3z"/><path d="M12 10v4.5"/><circle cx="12" cy="17.5" r="0.6" fill="currentColor"/></svg>'
const LOCK_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V8a4 4 0 1 1 8 0v2.5" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
const GLOBE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.7 2.6 4 5.6 4 9s-1.3 6.4-4 9c-2.7-2.6-4-5.6-4-9s1.3-6.4 4-9z"/></svg>'
const PERSON_2_FILL =
  '<svg viewBox="0 0 24 16" fill="currentColor"><circle cx="9" cy="5" r="3.4"/><path d="M9 9.4c-3.6 0-6.5 2.2-6.5 5v1.1h13v-1.1c0-2.8-2.9-5-6.5-5z"/><circle cx="17.4" cy="5.4" r="2.7"/><path d="M17.6 9.6c-.7 0-1.4.1-2 .35 1.5 1.1 2.4 2.7 2.4 4.45v1.1h3.9v-1.1c0-2.6-1.9-4.8-4.3-4.8z"/></svg>'
const BOOK_FILL =
  '<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 1.783C7.015.936 5.587.81 4.287.94c-1.514.153-3.042.672-4.013 1.448a.5.5 0 0 0-.274.446v11a.5.5 0 0 0 .727.446c.93-.468 2.34-.948 3.658-1.08 1.323-.133 2.452.063 3.072.638a.5.5 0 0 0 .654 0c.62-.575 1.75-.771 3.072-.638 1.318.132 2.728.612 3.658 1.08A.5.5 0 0 0 16 13.834v-11a.5.5 0 0 0-.274-.446c-.97-.776-2.499-1.295-4.013-1.448C10.413.809 8.985.936 8 1.783"/></svg>'
const CLOCK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>'
const ARROW_DOWN =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v15M5.5 12.5L12 19l6.5-6.5"/></svg>'

const MONTHS_ABBREV = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
// Range-panel weekday letters, Sun-first (iOS DayOfWeekPicker).
const PICKER_LETTERS = ['S', 'M', 'T', 'W', 'T', 'F', 'S']
// Confirm schedule card letters, Mon-first (iOS DayCircle row: indices 1…6,0).
const SCHEDULE_ORDER = [1, 2, 3, 4, 5, 6, 0]
const SCHEDULE_LETTERS = ['M', 'T', 'W', 'T', 'F', 'S', 'S']

const enabledSet = computed(() => new Set(props.enabledDays))

// ── Panel 0 ──
const panelZeroTitle = computed(() =>
  props.entry === 'program' ? 'Select Group' : 'Select Program'
)
const searchPlaceholder = computed(() =>
  props.entry === 'program' ? 'Search groups' : 'Search programs'
)
const listCount = computed(() =>
  props.entry === 'program' ? props.groups.length : props.programs.length
)
// iOS shouldShowSearch = !searchText.isEmpty || items.count > 10.
const showSearch = computed(() => props.searchText !== '' || listCount.value > 10)

function matches(name: string, description?: string): boolean {
  const q = props.searchText.trim().toLowerCase()
  if (!q) return true
  return (
    name.toLowerCase().includes(q) || (description ?? '').toLowerCase().includes(q)
  )
}

const filteredGroups = computed(() =>
  props.groups.filter((g) => matches(g.name, g.description))
)
const filteredPrograms = computed(() =>
  props.programs.filter((p) => matches(p.name, p.description))
)

const emptyText = computed(() => {
  if (props.entry === 'program') {
    return props.searchText ? 'No groups match your search' : 'No groups found'
  }
  return props.searchText ? 'No programs match your search' : 'No study programs found'
})

// iOS rightLinkDisabled: no selection (create flow — originalId is nil).
const panelZeroNextDisabled = computed(() =>
  props.entry === 'program' ? !props.selectedGroupId : !props.selectedProgramId
)

function groupMetadata(g: EnrollmentFlowGroupRow) {
  const items: Array<{ number: string; label: string }> = [
    { number: `${g.memberCount}`, label: 'Members' },
  ]
  if ((g.enrollmentCount ?? 0) > 0) {
    items.push({
      number: `${g.enrollmentCount}`,
      label: g.enrollmentCount === 1 ? 'Enrollment' : 'Enrollments',
    })
  }
  return items
}

function onProgramTap(p: EnrollmentFlowProgramRow): void {
  if (p.disabled) return
  if (p.isPublished === false) {
    emit('tapDraftProgram', p.id)
    return
  }
  emit('selectProgram', p.id)
}

// ── Panel 1 (dates) ──
function parseKey(key: string): { y: number; m: number; d: number } {
  const [y, m, d] = key.split('-').map(Number)
  return { y, m, d }
}

// iOS formattedDateRange: "SELECT START DATE" / '"MMM d" - "MMM d"' uppercased.
const rangeLabel = computed(() => {
  if (!props.startDate) return 'SELECT START DATE'
  const s = parseKey(props.startDate)
  const from = `${MONTHS_ABBREV[s.m - 1]} ${s.d}`.toUpperCase()
  if (!props.endDate) return from
  const e = parseKey(props.endDate)
  return `${from} - ${`${MONTHS_ABBREV[e.m - 1]} ${e.d}`.toUpperCase()}`
})

// ── Panel 2 (confirm) ──
function dateParts(key: string | null): { day: string; month: string } {
  if (!key) return { day: '—', month: '' }
  const p = parseKey(key)
  return { day: `${p.d}`, month: MONTHS_ABBREV[p.m - 1].toUpperCase() }
}

const confirmStart = computed(() => dateParts(props.startDate))
const confirmEnd = computed(() => dateParts(props.endDate))

// "7:30 AM" display from "HH:mm" (iOS native hourAndMinute picker value).
const smsTimeLabel = computed(() => {
  const [h, m] = props.smsTime.split(':').map(Number)
  const period = h >= 12 ? 'PM' : 'AM'
  const hour12 = h % 12 === 0 ? 12 : h % 12
  return `${hour12}:${m < 10 ? `0${m}` : m} ${period}`
})

const syncCaption = computed(() =>
  props.syncMode === 'Approval'
    ? 'You review updates and choose when to apply them.'
    : 'Published updates apply to future lessons right away.'
)
</script>

<template>
  <div :class="['EnrollmentFlow', props.class]">
    <div
      class="EnrollmentFlow__track"
      :style="{ transform: `translateX(${-props.step * (100 / 3)}%)` }"
    >
      <!-- ── Panel 0: Select Group / Select Program ── -->
      <section class="EnrollmentFlow__panel">
        <div class="EnrollmentFlow__scroll">
          <div
            class="EnrollmentFlow__listSpacer"
            :style="{ height: `${showSearch ? 140 : 70}px` }"
          ></div>

          <template v-if="props.listLoading">
            <div class="EnrollmentFlow__skeletons">
              <template v-if="props.entry === 'program'">
                <SkeletonCardGroup v-for="i in 4" :key="i" />
              </template>
              <template v-else>
                <SkeletonCardStudy v-for="i in 4" :key="i" />
              </template>
            </div>
          </template>

          <div v-else-if="props.listError" class="EnrollmentFlow__stateBlock">
            <span
              class="EnrollmentFlow__stateIcon EnrollmentFlow__stateIcon--warning"
              v-html="WARNING_TRIANGLE"
            ></span>
            <span class="EnrollmentFlow__stateText">{{ props.listError }}</span>
            <button
              type="button"
              class="EnrollmentFlow__retry"
              @click="emit('retry')"
            >
              Retry
            </button>
          </div>

          <div
            v-else-if="
              (props.entry === 'program' ? filteredGroups : filteredPrograms).length === 0
            "
            class="EnrollmentFlow__stateBlock"
          >
            <span class="EnrollmentFlow__stateIcon" v-html="MAGNIFYING_GLASS"></span>
            <span class="EnrollmentFlow__stateText">{{ emptyText }}</span>
          </div>

          <template v-else-if="props.entry === 'program'">
            <div
              v-for="g in filteredGroups"
              :key="g.id"
              class="EnrollmentFlow__row"
              :class="{ 'EnrollmentFlow__row--disabled': g.enrolled }"
            >
              <CardGroup
                :name="g.name"
                :image-url="g.imageUrl"
                icon-fallback
                :member-count="g.memberCount"
                :metadata="groupMetadata(g)"
                :selected="g.id === props.selectedGroupId"
                @click="!g.enrolled && emit('selectGroup', g.id)"
              />
            </div>
          </template>

          <template v-else>
            <CardStudySelectable
              v-for="p in filteredPrograms"
              :key="p.id"
              :title="p.name"
              :description="p.description"
              :count="p.days"
              :image-url="p.imageUrl"
              :is-published="p.isPublished !== false"
              :selected="p.id === props.selectedProgramId"
              :disabled="p.disabled"
              :enrolled-until="p.enrolledUntil"
              @click="onProgramTap(p)"
            />
          </template>
        </div>

        <!-- Header overlays the scroll (iOS .overlay(alignment: .top)) -->
        <div class="EnrollmentFlow__header">
          <div class="EnrollmentFlow__dragSpacer"></div>
          <PageTitle
            factory="iconTitleLink"
            :title="panelZeroTitle"
            :left-icon="XMARK"
            right-link="Next"
            :right-link-disabled="panelZeroNextDisabled"
            @left="emit('close')"
            @right="emit('next')"
          />
          <div v-if="showSearch" class="EnrollmentFlow__search">
            <SearchField
              is-active
              interactive
              :placeholder="searchPlaceholder"
              :search-text="props.searchText"
              @update:search-text="emit('update:searchText', $event)"
              @clear="emit('update:searchText', '')"
            />
          </div>
        </div>
      </section>

      <!-- ── Panel 1: Select dates ── -->
      <section class="EnrollmentFlow__panel">
        <div class="EnrollmentFlow__datesLayout">
          <div class="EnrollmentFlow__dragSpacer"></div>
          <PageTitle
            factory="iconTitleLink"
            title="Select dates"
            :left-icon="CHEVRON_LEFT"
            right-link="Next"
            :right-link-disabled="!props.startDate"
            @left="emit('back')"
            @right="emit('next')"
          />
          <div class="EnrollmentFlow__calendarScroll">
            <EnrollCalendar
              :start-month="props.calendarStartMonth"
              :month-count="props.calendarMonthCount"
              :today="props.calendarToday"
              :start-date="props.startDate"
              :end-date="props.endDate"
              :enabled-days="props.enabledDays"
              :overridden-dates="props.overriddenDates"
              :existing-lesson-dates="props.existingLessonDates"
              @select-date="emit('selectDate', $event)"
              @longpress-date="emit('longpressDate', $event)"
            />
          </div>
          <!-- SelectedRangePanel (iOS .ultraThinMaterial, top radius 8) -->
          <div class="EnrollmentFlow__rangePanel">
            <div class="EnrollmentFlow__rangeLabel">{{ rangeLabel }}</div>
            <div class="EnrollmentFlow__dayPicker">
              <button
                v-for="(letter, wi) in PICKER_LETTERS"
                :key="wi"
                type="button"
                class="EnrollmentFlow__dayToggle"
                :class="{ 'EnrollmentFlow__dayToggle--on': enabledSet.has(wi) }"
                @click="emit('toggleWeekday', wi)"
              >
                {{ letter }}
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- ── Panel 2: Confirm enrollment ── -->
      <section class="EnrollmentFlow__panel">
        <div class="EnrollmentFlow__confirmLayout">
          <div class="EnrollmentFlow__dragSpacer"></div>
          <PageTitle
            factory="iconTitleLink"
            title="Confirm enrollment"
            :left-icon="CHEVRON_LEFT"
            right-link="Confirm"
            @left="emit('back')"
            @right="emit('confirm')"
          />
          <div class="EnrollmentFlow__confirmScroll">
            <!-- Overview card -->
            <div class="EnrollmentFlow__overviewCard">
              <div class="EnrollmentFlow__overviewRow">
                <div class="EnrollmentFlow__overviewBody">
                  <span class="EnrollmentFlow__overviewName">{{
                    props.confirmGroup?.name
                  }}</span>
                  <span
                    v-if="props.confirmGroup?.description"
                    class="EnrollmentFlow__overviewDesc EnrollmentFlow__overviewDesc--group"
                    >{{ props.confirmGroup.description }}</span
                  >
                  <span class="EnrollmentFlow__overviewMeta">
                    <span
                      class="EnrollmentFlow__overviewMetaIcon"
                      v-html="props.confirmGroup?.isPrivate ? LOCK_FILL : GLOBE"
                    ></span>
                    {{ props.confirmGroup?.isPrivate ? 'Private group' : 'Public group' }}
                  </span>
                </div>
                <div class="EnrollmentFlow__overviewImage">
                  <img
                    v-if="props.confirmGroup?.imageUrl"
                    :src="props.confirmGroup.imageUrl"
                    :alt="props.confirmGroup.name"
                  />
                  <span
                    v-else
                    class="EnrollmentFlow__overviewFallback"
                    v-html="PERSON_2_FILL"
                  ></span>
                </div>
              </div>

              <span class="EnrollmentFlow__overviewArrow" v-html="ARROW_DOWN"></span>

              <div class="EnrollmentFlow__overviewRow">
                <div class="EnrollmentFlow__overviewBody">
                  <span class="EnrollmentFlow__overviewName">{{
                    props.confirmProgram?.name
                  }}</span>
                  <span
                    v-if="props.confirmProgram?.description"
                    class="EnrollmentFlow__overviewDesc EnrollmentFlow__overviewDesc--program"
                    >{{ props.confirmProgram.description }}</span
                  >
                  <span class="EnrollmentFlow__overviewMeta">
                    <span class="EnrollmentFlow__overviewMetaIcon" v-html="CLOCK"></span>
                    {{ props.confirmProgram?.days }} days
                  </span>
                </div>
                <div class="EnrollmentFlow__overviewImage">
                  <img
                    v-if="props.confirmProgram?.imageUrl"
                    :src="props.confirmProgram.imageUrl"
                    :alt="props.confirmProgram.name"
                  />
                  <span
                    v-else
                    class="EnrollmentFlow__overviewFallback"
                    v-html="BOOK_FILL"
                  ></span>
                </div>
              </div>
            </div>

            <!-- Members stats card -->
            <div class="EnrollmentFlow__statsCard">
              <div class="EnrollmentFlow__stat">
                <span class="EnrollmentFlow__statValue">{{
                  props.confirmGroup?.memberCount ?? 0
                }}</span>
                <span class="EnrollmentFlow__statLabel">Members included</span>
              </div>
              <div class="EnrollmentFlow__stat">
                <span class="EnrollmentFlow__statValue">0</span>
                <span class="EnrollmentFlow__statLabel">Members excluded</span>
              </div>
            </div>

            <!-- Schedule card -->
            <div class="EnrollmentFlow__scheduleCard">
              <div class="EnrollmentFlow__scheduleDate">
                <span class="EnrollmentFlow__scheduleDay">{{ confirmStart.day }}</span>
                <span class="EnrollmentFlow__scheduleMonth">{{ confirmStart.month }}</span>
              </div>
              <div class="EnrollmentFlow__scheduleCenter">
                <span class="EnrollmentFlow__scheduleCaption"
                  >{{ props.confirmProgram?.days }} day study</span
                >
                <div class="EnrollmentFlow__scheduleDays">
                  <span
                    v-for="(wi, i) in SCHEDULE_ORDER"
                    :key="i"
                    class="EnrollmentFlow__dayCircle"
                    :class="{ 'EnrollmentFlow__dayCircle--on': enabledSet.has(wi) }"
                    >{{ SCHEDULE_LETTERS[i] }}</span
                  >
                </div>
              </div>
              <div class="EnrollmentFlow__scheduleDate">
                <span class="EnrollmentFlow__scheduleDay">{{ confirmEnd.day }}</span>
                <span class="EnrollmentFlow__scheduleMonth">{{ confirmEnd.month }}</span>
              </div>
            </div>

            <!-- Send invites -->
            <div class="EnrollmentFlow__invitesRow">
              <span class="EnrollmentFlow__invitesLabel">Send invites</span>
              <span class="EnrollmentFlow__timeWell">
                {{ smsTimeLabel }}
                <input
                  v-if="props.interactive"
                  class="EnrollmentFlow__timeInput"
                  type="time"
                  :value="props.smsTime"
                  @change="
                    emit('update:smsTime', ($event.target as HTMLInputElement).value)
                  "
                />
              </span>
            </div>

            <!-- Require response -->
            <div class="EnrollmentFlow__fieldCard">
              <ToggleControl
                bare
                title="Require response"
                description="Members must submit a response for each activity before continuing."
                :is-on="props.requireResponse"
                @toggle="emit('update:requireResponse', !props.requireResponse)"
              />
            </div>

            <!-- Sync to study -->
            <div class="EnrollmentFlow__fieldCard">
              <ToggleControl
                bare
                title="Sync to study"
                description="Keep this group's lessons up to date when the study publishes changes. Completed lessons are never changed."
                :is-on="props.syncToStudy"
                @toggle="emit('update:syncToStudy', !props.syncToStudy)"
              />
            </div>

            <div v-if="props.syncToStudy" class="EnrollmentFlow__syncBlock">
              <MenuInput
                label="Updates"
                picker-style="segmented"
                :options="['Automatic', 'Approval']"
                :selected-value="props.syncMode"
                :interactive="props.interactive"
                @update:selected-value="
                  emit('update:syncMode', $event as 'Automatic' | 'Approval')
                "
              />
              <span class="EnrollmentFlow__syncCaption">{{ syncCaption }}</span>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
