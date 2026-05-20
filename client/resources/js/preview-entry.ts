/**
 * preview-entry.ts
 *
 * Vite entry for the canonical activity preview page.
 * Mounted at /preview/activity/:id by PreviewController::authenticatedActivityPreview.
 *
 * Reads `window.__PREVIEW_DATA__` (serialized by the Blade view).
 * Routes to the correct player based on activity type:
 *   - READ / SCRIPTURE → ActivityPreviewPlayer (full-screen themed reader)
 *   - All other types  → LessonIsland with singleActivity=true
 */

import { createApp } from 'vue'
import ActivityPreviewPlayer from './preview/ActivityPreviewPlayer.vue'
import LessonIsland from './components/domain/lesson-island/lesson-island.vue'

const data = (window as any).__PREVIEW_DATA__
const activity = data?.activity ?? data

const activityType = (activity?.type ?? activity?.activityType ?? 'READ').toUpperCase()
const isRead = activityType === 'READ' || activityType === 'SCRIPTURE'


if (isRead) {
  createApp(ActivityPreviewPlayer).mount('#preview-app')
} else {
  // Wrap the activity in a minimal lesson structure for LessonIsland.
  const lessonData = {
    lesson: {
      id: 'preview',
      title: activity?.title ?? 'Preview',
      activities: [activity],
    },
  }
  createApp(LessonIsland, {
    lessonData,
    groupId: '',
    lessonScheduleId: '',
    initialStep: 1,
    isPreview: true,
    singleActivity: true,
  }).mount('#preview-app')
}
