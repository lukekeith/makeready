<script setup lang="ts">
// EnrollmentSyncPane — the compact "Sync to study" settings view for one
// enrollment (study-sync phase 6). Reached as a SlideStack detail from the
// Program Home Enrollments tab and from notification actions with
// view: 'enrollment-sync'. Shows the sync toggle (OFF ↔ AUTO/APPROVAL), the
// mode chooser, drift status with the pending versions' AI change summaries,
// and the "Apply updates" action (approval acceptance / manual catch-up).
import { computed, onMounted } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import ToggleControl from '../../../components/card/toggle-control/toggle-control.vue'
import BoxButton from '../../../components/card/box-button/box-button.vue'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import {
  useLeaderEnrollmentSync,
  type SyncMode,
} from '../stores/leader-enrollment-sync.store'
import { relativeTime } from '../stores/leader-notifications.store'

const props = defineProps<{
  enrollmentId: string
  /** Optional context line under the title (e.g. the group's name). */
  groupName?: string
}>()

const emit = defineEmits<{ back: [] }>()

const store = useLeaderEnrollmentSync()
const confirmDialog = useConfirmDialog()

onMounted(() => {
  void store.load(props.enrollmentId)
})

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'
const CHECK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5l5 5 10-11"/></svg>'

const syncOn = computed(() => (store.status?.syncMode ?? 'OFF') !== 'OFF')

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

async function onApply(): Promise<void> {
  if (store.applying) return
  const choice = await confirmDialog.confirm({
    title: 'Apply updates?',
    message:
      "This brings the group's future lessons up to the latest published version. Lessons members already completed are never changed.",
    buttons: [
      { label: 'Apply updates', style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0) return
  try {
    await store.apply(props.enrollmentId)
    void confirmDialog.confirm({
      title: 'Updates applied',
      message: 'This enrollment now has the latest version of the study.',
      buttons: [{ label: 'OK', style: 'secondary' }],
    })
  } catch (err) {
    showError(err instanceof Error ? err.message : "Couldn't apply the updates")
  }
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

        <!-- Drift: pending versions + apply -->
        <div v-if="store.status.hasDrift" class="EnrollmentSyncPane__section">
          <p class="EnrollmentSyncPane__label">Updates available</p>
          <div class="EnrollmentSyncPane__versions">
            <div
              v-for="v in store.status.pendingVersions"
              :key="v.versionNumber"
              class="EnrollmentSyncPane__version"
            >
              <span class="EnrollmentSyncPane__versionHead">
                Version {{ v.versionNumber }}
                <span class="EnrollmentSyncPane__versionTime">{{ relativeTime(v.publishedAt) }}</span>
              </span>
              <span v-if="v.changeSummary" class="EnrollmentSyncPane__versionSummary">
                {{ v.changeSummary }}
              </span>
            </div>
          </div>
          <BoxButton
            class="EnrollmentSyncPane__apply"
            :label="store.applying ? 'Applying...' : 'Apply updates'"
            variant="primary"
            size="lg"
            full-width
            @click="onApply"
          />
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
</template>

<style scoped>
.EnrollmentSyncPane {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: var(--color-canvas);
  color: #fff;
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

.EnrollmentSyncPane__versions {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.EnrollmentSyncPane__version {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px 16px;
  border-radius: 10px;
  background: var(--color-white-10);
}

.EnrollmentSyncPane__versionHead {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  font-size: 15px;
  font-weight: 600;
}

.EnrollmentSyncPane__versionTime {
  font-size: 13px;
  font-weight: 400;
  color: var(--color-white-50);
}

.EnrollmentSyncPane__versionSummary {
  font-size: 13px;
  line-height: 1.4;
  color: var(--color-white-50);
  white-space: pre-line;
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
