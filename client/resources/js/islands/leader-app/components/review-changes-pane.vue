<script setup lang="ts">
// ReviewChangesPane — per-lesson approval of pending study-sync updates
// (web twin of iPhone ReviewChangesPage; SlideStack detail of the
// enrollment-sync pane). Grid rows: date + colored new/updated/deleted tag on
// the left, quantified change summary + per-lesson toggle on the right.
// "Approve" in the PageTitle applies the toggled-on lessons; rejected changes
// stay pending for a later visit.
import { computed, onMounted, reactive } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import ToggleControl from '../../../components/card/toggle-control/toggle-control.vue'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import {
  useLeaderEnrollmentSync,
  type PendingLessonChange,
} from '../stores/leader-enrollment-sync.store'

const props = defineProps<{ enrollmentId: string }>()
const emit = defineEmits<{ back: [] }>()

const store = useLeaderEnrollmentSync()
const confirmDialog = useConfirmDialog()

// Per-lesson approval toggles, keyed by change key. Default ON.
const approved = reactive<Record<string, boolean>>({})

onMounted(async () => {
  await store.loadChanges(props.enrollmentId)
  for (const change of store.changes) {
    if (!(change.key in approved)) approved[change.key] = true
  }
})

const approvedKeys = computed(() =>
  store.changes.map((c) => c.key).filter((key) => approved[key] ?? true),
)

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'

const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC']

function dateParts(change: PendingLessonChange): { top: string; bottom: string } {
  if (change.scheduledDate) {
    const d = new Date(change.scheduledDate)
    return { top: MONTHS[d.getMonth()], bottom: String(d.getDate()) }
  }
  return { top: 'DAY', bottom: change.dayNumber != null ? String(change.dayNumber) : '–' }
}

function tagLabel(type: PendingLessonChange['type']): string {
  return type === 'new' ? 'NEW' : type === 'updated' ? 'UPDATED' : 'DELETED'
}

// Quantified per-lesson summary: activity counts + title changes.
function changeSummary(change: PendingLessonChange): string {
  if (change.type === 'removed') {
    const n = change.activities?.removed ?? 0
    return n > 0 ? `Lesson removed (${n} ${n === 1 ? 'activity' : 'activities'})` : 'Lesson removed'
  }
  if (change.type === 'new') {
    const n = change.activities?.added ?? 0
    return n > 0 ? `New lesson with ${n} ${n === 1 ? 'activity' : 'activities'}` : 'New lesson'
  }
  const parts: string[] = []
  if (change.activities) {
    if (change.activities.updated) parts.push(`${change.activities.updated} updated`)
    if (change.activities.added) parts.push(`${change.activities.added} added`)
    if (change.activities.removed) parts.push(`${change.activities.removed} removed`)
  }
  let line = parts.length ? `Activities: ${parts.join(' · ')}` : ''
  if (change.titleChanged) line = line ? `${line}\nTitle changed` : 'Title changed'
  return line || 'Content updated'
}

async function approveSelected(): Promise<void> {
  if (store.applying || !approvedKeys.value.length) return
  try {
    await store.apply(props.enrollmentId, approvedKeys.value)
    emit('back')
  } catch (err) {
    void confirmDialog.confirm({
      title: 'Something went wrong',
      message: err instanceof Error ? err.message : "Couldn't apply the updates",
      buttons: [{ label: 'OK', style: 'secondary' }],
    })
  }
}
</script>

<template>
  <div class="ReviewChangesPane">
    <PageTitle
      class="ReviewChangesPane__title"
      title="Review Changes"
      :left-icon="BACK_CHEVRON"
      :right-link="approvedKeys.length ? (store.applying ? 'Approving...' : 'Approve') : ''"
      @left="emit('back')"
      @right="approveSelected"
    />

    <div class="ReviewChangesPane__scroll">
      <div v-if="store.changesLoading && !store.changes.length" class="ReviewChangesPane__state">
        Loading…
      </div>
      <div v-else-if="!store.changes.length" class="ReviewChangesPane__state">
        All caught up — this enrollment has the latest version.
      </div>

      <template v-else>
        <div v-for="change in store.changes" :key="change.key" class="ReviewChangesPane__row">
          <div class="ReviewChangesPane__date">
            <span class="ReviewChangesPane__dateTop">{{ dateParts(change).top }}</span>
            <span class="ReviewChangesPane__dateBottom">{{ dateParts(change).bottom }}</span>
            <span
              class="ReviewChangesPane__tag"
              :class="`ReviewChangesPane__tag--${change.type}`"
            >
              {{ tagLabel(change.type) }}
            </span>
          </div>

          <div class="ReviewChangesPane__detail">
            <span v-if="change.title" class="ReviewChangesPane__lessonTitle">
              {{ change.title }}
            </span>
            <span class="ReviewChangesPane__summary">{{ changeSummary(change) }}</span>
          </div>

          <ToggleControl
            class="ReviewChangesPane__toggle"
            bare
            :is-on="approved[change.key] ?? true"
            @toggle="approved[change.key] = !(approved[change.key] ?? true)"
          />
        </div>
      </template>

      <div class="ReviewChangesPane__bottomSpacer"></div>
    </div>
  </div>
</template>

<style scoped>
.ReviewChangesPane {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: var(--color-canvas);
  color: #fff;
}

.ReviewChangesPane__title {
  flex: 0 0 auto;
}

.ReviewChangesPane__scroll {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 16px 16px 0;
  overflow-y: auto;
  min-height: 0;
}

.ReviewChangesPane__state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  font-size: 15px;
  color: var(--color-white-50);
}

.ReviewChangesPane__row {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px;
  border-radius: 10px;
  background: var(--color-white-10);
}

/* Left column: date + colored change tag. */
.ReviewChangesPane__date {
  flex: 0 0 64px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.ReviewChangesPane__dateTop {
  font-size: 13px;
  font-weight: 700;
  color: #6c47ff;
}

.ReviewChangesPane__dateBottom {
  font-size: 22px;
  font-weight: 700;
}

.ReviewChangesPane__tag {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.4px;
  color: var(--color-canvas);
}

/* iOS Colors: success #57DB5D, warning #F4FF76, destructive #df1439. */
.ReviewChangesPane__tag--new {
  background: #57db5d;
}

.ReviewChangesPane__tag--updated {
  background: #f4ff76;
}

.ReviewChangesPane__tag--removed {
  background: #df1439;
  color: #fff;
}

.ReviewChangesPane__detail {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.ReviewChangesPane__lessonTitle {
  font-size: 15px;
  font-weight: 600;
  line-height: 1.3;
}

.ReviewChangesPane__summary {
  font-size: 13px;
  line-height: 1.4;
  color: var(--color-white-50);
  white-space: pre-line;
}

/* Bare ToggleControl renders without card chrome; strip its row padding and
   collapse the empty text column so only the pill sits in the grid row. */
.ReviewChangesPane__toggle {
  flex: 0 0 auto;
}

.ReviewChangesPane__toggle :deep(.ToggleControl__row) {
  padding: 0;
}

.ReviewChangesPane__toggle :deep(.ToggleControl__text) {
  display: none;
}

.ReviewChangesPane__bottomSpacer {
  flex: 0 0 24px;
}
</style>
