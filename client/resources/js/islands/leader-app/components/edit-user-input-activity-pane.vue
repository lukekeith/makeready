<script setup lang="ts">
// EditUserInputActivityPane — thin production wrapper around the shared
// EditUserInputActivity twin (components/card/edit-user-input-activity), the
// web twin of the iPhone EditUserInputActivityPage (a nested SlideStack
// detail inside EditDay). All layout lives in the twin; this wrapper maps
// LeaderActivity → twin props (iOS seeds the title field with
// activity.title ?? type.displayName — "Study" for USER_INPUT) and opens the
// lesson preview URL the iOS Preview button targets.
import EditUserInputActivity from '../../../components/card/edit-user-input-activity/edit-user-input-activity.vue'
import type { LeaderActivity } from '../stores/leader-program.store'

const props = defineProps<{
  activity: LeaderActivity
  saving?: boolean
  /** iOS Preview → client /preview/lesson/{lessonId}/{step}; omit to hide. */
  previewUrl?: string
}>()

const emit = defineEmits<{
  cancel: []
  save: [fields: {
    title: string
    placeholder: string
    isHelpEnabled: boolean
    helpTitle: string
    helpDescription: string
  }]
}>()

function openPreview(): void {
  if (props.previewUrl) window.open(props.previewUrl, '_blank', 'noopener')
}
</script>

<template>
  <EditUserInputActivity
    interactive
    :title="props.activity.title || 'Study'"
    :placeholder="props.activity.placeholder"
    :help-enabled="props.activity.isHelpEnabled"
    :help-title="props.activity.helpTitle"
    :help-description="props.activity.helpDescription"
    :saving="props.saving"
    :show-preview="!!props.previewUrl"
    @cancel="emit('cancel')"
    @save="emit('save', $event)"
    @preview="openPreview"
  />
</template>
