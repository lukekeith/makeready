<script setup lang="ts">
// EnrollmentSyncPane — the compact "Sync to study" settings view for one
// enrollment (study-sync phase 6). Reached as a SlideStack detail from the
// Program Home Enrollments tab and from notification actions with
// view: 'enrollment-sync'. Shows the sync toggle (OFF ↔ AUTO/APPROVAL), the
// mode chooser, and — when the enrollment is behind — a quantified summary
// card (lesson + activity counts) that slides to the Review Changes pane for
// per-lesson approval.
import { computed, onMounted, ref } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import ToggleControl from '../../../components/card/toggle-control/toggle-control.vue'
import SlideStack from '../overlay/slide-stack.vue'
import ReviewChangesPane from './review-changes-pane.vue'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import {
  useLeaderEnrollmentSync,
  type SyncMode,
} from '../stores/leader-enrollment-sync.store'

const props = defineProps<{
  enrollmentId: string
  /** Optional context line under the title (e.g. the group's name). */
  groupName?: string
}>()

const emit = defineEmits<{ back: [] }>()

const store = useLeaderEnrollmentSync()
const confirmDialog = useConfirmDialog()

// Inner SlideStack: the Review Changes pane.
const showReview = ref(false)

onMounted(() => {
  void store.load(props.enrollmentId)
  void store.loadChanges(props.enrollmentId)
})

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'
const CHECK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5l5 5 10-11"/></svg>'
const CHEVRON_RIGHT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4l7 8-7 8"/></svg>'

const syncOn = computed(() => (store.status?.syncMode ?? 'OFF') !== 'OFF')

// One matrix row: "2 updated · 1 new · 1 removed" (empty rows hidden).
function countLine(updated: number, added: number, removed: number): string {
  return [
    updated > 0 ? `${updated} updated` : null,
    added > 0 ? `${added} new` : null,
    removed > 0 ? `${removed} removed` : null,
  ]
    .filter(Boolean)
    .join(' · ')
}

const lessonCounts = computed(() =>
  store.counts
    ? countLine(store.counts.lessonsUpdated, store.counts.lessonsNew, store.counts.lessonsRemoved)
    : '',
)
const activityCounts = computed(() =>
  store.counts
    ? countLine(
        store.counts.activitiesUpdated,
        store.counts.activitiesNew,
        store.counts.activitiesRemoved,
      )
    : '',
)

function showError(message: string): void {
  void confirmDialog.confirm({
    title: 'Something went wrong',
    message,
    buttons: [{ label: 'OK', style: 'secondary' }],
  })
}

async function setMode(mode: SyncMode): Promise<void> {
  if (!store.status || store.status.syncMode === mode) return
  try {
    await store.setMode(props.enrollmentId, mode)
  } catch (err) {
    showError(err instanceof Error ? err.message : "Couldn't update sync settings")
  }
}

// Toggle on defaults to Automatic (the leader can switch to Approval below).
function onToggle(): void {
  void setMode(syncOn.value ? 'OFF' : 'AUTO')
}

const MODES: Array<{ mode: SyncMode; title: string; description: string }> = [
  {
    mode: 'AUTO',
    title: 'Automatic',
    description: 'Published updates apply to future lessons right away.',
  },
  {
    mode: 'APPROVAL',
    title: 'Approval required',
    description: 'You review updates and choose when to apply them.',
  },
]
</script>

<template>
  <div class="EnrollmentSyncPane">
    <SlideStack :item="showReview || null">
      <div class="EnrollmentSyncPane__main">
        <PageTitle
          class="EnrollmentSyncPane__title"
          title="Study Sync"
          :left-icon="BACK_CHEVRON"
          @left="emit('back')"
        />

        <div class="EnrollmentSyncPane__scroll">
      <div v-if="store.loading" class="EnrollmentSyncPane__state">Loading…</div>
      <div v-else-if="store.error" class="EnrollmentSyncPane__state">{{ store.error }}</div>

      <template v-else-if="store.status">
        <p v-if="props.groupName" class="EnrollmentSyncPane__context">{{ props.groupName }}</p>

        <!-- Sync toggle -->
        <div class="EnrollmentSyncPane__section">
          <ToggleControl
            title="Sync to study"
            description="Keep this group's lessons up to date when the study publishes changes. Completed lessons are never changed."
            :is-on="syncOn"
            @toggle="onToggle"
          />
        </div>

        <!-- Mode chooser (only while sync is on) -->
        <div v-if="syncOn" class="EnrollmentSyncPane__section">
          <div class="EnrollmentSyncPane__modes">
            <button
              v-for="m in MODES"
              :key="m.mode"
              class="EnrollmentSyncPane__mode"
              type="button"
              @click="setMode(m.mode)"
            >
              <span class="EnrollmentSyncPane__modeText">
                <span class="EnrollmentSyncPane__modeTitle">{{ m.title }}</span>
                <span class="EnrollmentSyncPane__modeDesc">{{ m.description }}</span>
              </span>
              <span
                class="EnrollmentSyncPane__modeCheck"
                :class="{ 'EnrollmentSyncPane__modeCheck--on': store.status.syncMode === m.mode }"
                v-html="CHECK"
              ></span>
            </button>
          </div>
        </div>

        <!-- Drift: quantified summary card → Review Changes -->
        <div v-if="store.status.hasDrift" class="EnrollmentSyncPane__section">
          <p class="EnrollmentSyncPane__label">Updates available</p>
          <button class="EnrollmentSyncPane__summaryCard" type="button" @click="showReview = true">
            <span class="EnrollmentSyncPane__summaryCounts">
              <template v-if="store.counts">
                <span v-if="lessonCounts" class="EnrollmentSyncPane__countRow">
                  <span class="EnrollmentSyncPane__countLabel">Lessons</span>
                  <span class="EnrollmentSyncPane__countValue">{{ lessonCounts }}</span>
                </span>
                <span v-if="activityCounts" class="EnrollmentSyncPane__countRow">
                  <span class="EnrollmentSyncPane__countLabel">Activities</span>
                  <span class="EnrollmentSyncPane__countValue">{{ activityCounts }}</span>
                </span>
              </template>
              <span v-else class="EnrollmentSyncPane__countValue">Review pending changes</span>
            </span>
            <span class="EnrollmentSyncPane__summaryChevron" v-html="CHEVRON_RIGHT"></span>
          </button>
        </div>

        <!-- Up to date -->
        <div v-else class="EnrollmentSyncPane__section">
          <p class="EnrollmentSyncPane__upToDate">
            Up to date{{
              store.status.currentVersionNumber != null
                ? ` — version ${store.status.currentVersionNumber}`
                : ''
            }}
          </p>
        </div>
      </template>

          <div class="EnrollmentSyncPane__bottomSpacer"></div>
        </div>
      </div>

      <template #detail>
        <ReviewChangesPane :enrollment-id="props.enrollmentId" @back="showReview = false" />
      </template>
    </SlideStack>
  </div>
</template>

<style scoped>
.EnrollmentSyncPane {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: var(--color-canvas);
  color: #fff;
}

.EnrollmentSyncPane :deep(.SlideStack) {
  flex: 1 1 auto;
  min-height: 0;
}

.EnrollmentSyncPane__main {
  height: 100%;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.EnrollmentSyncPane :deep(.ReviewChangesPane) {
  height: 100%;
  min-height: 0;
}

.EnrollmentSyncPane__title {
  flex: 0 0 auto;
}

.EnrollmentSyncPane__scroll {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  gap: 20px;
  overflow-y: auto;
  min-height: 0;
}

.EnrollmentSyncPane__state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 15px;
  color: var(--color-white-50);
}

.EnrollmentSyncPane__context {
  padding: 0 16px;
  font-size: 13px;
  font-weight: 600;
  color: var(--color-white-50);
}

.EnrollmentSyncPane__section {
  padding: 0 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

/* Mode rows — one white@10 card, rows separated by a hairline. */
.EnrollmentSyncPane__modes {
  display: flex;
  flex-direction: column;
  border-radius: 10px;
  background: var(--color-white-10);
  overflow: hidden;
}

.EnrollmentSyncPane__mode {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  border: none;
  background: none;
  color: inherit;
  text-align: left;
  cursor: pointer;
}

.EnrollmentSyncPane__mode + .EnrollmentSyncPane__mode {
  border-top: 1px solid var(--color-white-10);
}

.EnrollmentSyncPane__modeText {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.EnrollmentSyncPane__modeTitle {
  font-size: 17px;
}

.EnrollmentSyncPane__modeDesc {
  font-size: 13px;
  color: var(--color-white-50);
}

.EnrollmentSyncPane__modeCheck {
  flex: 0 0 auto;
  width: 20px;
  height: 20px;
  opacity: 0;
  color: #57db5d;
}

.EnrollmentSyncPane__modeCheck--on {
  opacity: 1;
}

.EnrollmentSyncPane__modeCheck :deep(svg) {
  width: 100%;
  height: 100%;
  display: block;
}

.EnrollmentSyncPane__label {
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: var(--color-white-50);
}

/* Quantified summary card — counts matrix + right chevron, tap to review. */
.EnrollmentSyncPane__summaryCard {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  border: none;
  border-radius: 10px;
  background: var(--color-white-10);
  color: inherit;
  text-align: left;
  cursor: pointer;
}

.EnrollmentSyncPane__summaryCounts {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.EnrollmentSyncPane__countRow {
  display: flex;
  align-items: baseline;
  gap: 8px;
}

.EnrollmentSyncPane__countLabel {
  flex: 0 0 72px;
  font-size: 13px;
  font-weight: 600;
  color: var(--color-white-50);
}

.EnrollmentSyncPane__countValue {
  font-size: 15px;
}

.EnrollmentSyncPane__summaryChevron {
  flex: 0 0 auto;
  width: 14px;
  height: 14px;
  color: var(--color-white-50);
}

.EnrollmentSyncPane__summaryChevron :deep(svg) {
  width: 100%;
  height: 100%;
  display: block;
}

.EnrollmentSyncPane__upToDate {
  padding: 12px 16px;
  border-radius: 10px;
  background: var(--color-white-5);
  font-size: 15px;
  color: var(--color-white-50);
}

.EnrollmentSyncPane__bottomSpacer {
  flex: 0 0 40px;
}
</style>
