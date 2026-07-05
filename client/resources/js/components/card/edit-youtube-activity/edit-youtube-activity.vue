<script setup lang="ts">
import { computed, ref } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import TextInput from '../text-input/text-input.vue'
import BoxButton from '../box-button/box-button.vue'

// EditYouTubeActivity — web twin of the iPhone YouTube-activity editor
// (Pages/Manage/Program/EditYouTubeActivityPage.swift, a nested SlideStack
// detail inside EditDay). Data-driven and shared by BOTH the capture compare
// harness (inert, props seed the form) and the production pane (interactive
// + emits).
//
// Layout (iOS ScrollView → VStack spacing 20, top pad 16, bottom pad 40,
// sections H16):
//   • PageTitle.linkTitleLink — Cancel / "YouTube Video" /
//     Saving... | Save (has changes) | Done
//   • FieldGroup { TextInput floating "Activity title" }
//   • FieldGroup { TextInput floating "YouTube URL" }
//   • when the URL parses: YouTubePreview — 16:9 rounded-12 well
//     (thumbnail img when it resolves, white@5% fill otherwise) with a
//     centered play.circle.fill glyph (s48 white@0.9, shadow). Tap opens
//     the video (production emits; capture binds nothing).
//   • "Loading video info..." row while metadata fetches (production only)
//   • BoxButton "Preview" (eye right, secondary solid lg fullWidth)
//
// The thumbnail is a remote image (img.youtube.com) — iPhone snapshots never
// resolve remote images, so capture adapters omit it and both sides render
// the white@5% placeholder + play glyph.

interface Props {
  title?: string
  youtubeUrl?: string
  /** Thumbnail for the preview well. Captures omit it (remote-image rule). */
  thumbnailUrl?: string
  fetchingMetadata?: boolean
  saving?: boolean
  /** iOS shows Preview only when programId is present (always, in captures). */
  showPreview?: boolean
  /** Production: inputs become editable. Capture never passes it. */
  interactive?: boolean
  // Capture-only: render the iOS device status bar (the iPhone reference
  // includes the simulator's). Production never passes this.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  youtubeUrl: '',
  thumbnailUrl: '',
  fetchingMetadata: false,
  saving: false,
  showPreview: true,
  interactive: false,
  statusBar: false,
})

const emit = defineEmits<{
  cancel: []
  save: [fields: { title: string; youtubeUrl: string }]
  preview: []
  openVideo: [videoId: string]
  'update:youtubeUrl': [value: string]
}>()

// Local editable state seeded from props (iOS onAppear snapshot).
const title = ref(props.title)
const url = ref(props.youtubeUrl)

// iOS youtubeVideoId — same four URL patterns.
function parseVideoId(value: string): string | null {
  const patterns = [
    /(?:v=)([a-zA-Z0-9_-]{11})/,
    /(?:youtu\.be\/)([a-zA-Z0-9_-]{11})/,
    /(?:embed\/)([a-zA-Z0-9_-]{11})/,
    /(?:shorts\/)([a-zA-Z0-9_-]{11})/,
  ]
  for (const pattern of patterns) {
    const match = value.match(pattern)
    if (match) return match[1]
  }
  return null
}

const videoId = computed(() => parseVideoId(url.value.trim()))

const hasChanges = computed(
  () => title.value !== props.title || url.value !== props.youtubeUrl,
)

const rightLink = computed(() =>
  props.saving ? 'Saving...' : hasChanges.value ? 'Save' : 'Done',
)

function save(): void {
  if (props.saving) return
  emit('save', { title: title.value.trim(), youtubeUrl: url.value.trim() })
}

function onUrlInput(value: string): void {
  url.value = value
  emit('update:youtubeUrl', value)
}

// SF "eye" — Preview button glyph.
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
</script>

<template>
  <div :class="['EditYouTubeActivity', props.class]">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="EditYouTubeActivity__statusbar" aria-hidden="true">
      <span class="EditYouTubeActivity__clock">9:41</span>
      <span class="EditYouTubeActivity__indicators">
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" />
          <rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" />
        </svg>
        <svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor">
          <path d="M8.5 2C5.6 2 3 3.1 1 4.9l1.4 1.5C4 4.9 6.1 4 8.5 4s4.5.9 6.1 2.4L16 4.9C14 3.1 11.4 2 8.5 2z" />
          <path d="M8.5 6.2c-1.6 0-3 .6-4.1 1.6l1.5 1.5c.7-.6 1.6-1 2.6-1s1.9.4 2.6 1l1.5-1.5C11.5 6.8 10.1 6.2 8.5 6.2z" />
          <circle cx="8.5" cy="11" r="1.3" />
        </svg>
        <svg width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="currentColor" stroke-opacity="0.4" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4z" fill="currentColor" fill-opacity="0.4" />
        </svg>
      </span>
    </div>

    <PageTitle
      title="YouTube Video"
      left-link="Cancel"
      :right-link="rightLink"
      @left="emit('cancel')"
      @right="save"
    />

    <div class="EditYouTubeActivity__scroll">
      <div class="EditYouTubeActivity__section">
        <div class="FieldGroup">
          <TextInput
            :interactive="props.interactive"
            floating-label="Activity title"
            :text="title"
            @update:text="title = $event"
          />
        </div>
      </div>

      <div class="EditYouTubeActivity__section">
        <div class="FieldGroup">
          <TextInput
            :interactive="props.interactive"
            floating-label="YouTube URL"
            :text="url"
            @update:text="onUrlInput"
          />
        </div>
      </div>

      <div v-if="videoId" class="EditYouTubeActivity__section">
        <button
          type="button"
          class="EditYouTubeActivity__preview"
          @click="emit('openVideo', videoId)"
        >
          <img
            v-if="props.thumbnailUrl"
            class="EditYouTubeActivity__thumb"
            :src="props.thumbnailUrl"
            alt=""
          />
          <span class="EditYouTubeActivity__play" aria-hidden="true">
            <svg viewBox="0 0 48 48" fill="currentColor">
              <circle cx="24" cy="24" r="22" fill="currentColor" />
              <path d="M20 16.5v15l12-7.5z" fill="var(--color-canvas)" />
            </svg>
          </span>
        </button>
      </div>

      <div v-if="videoId && props.fetchingMetadata" class="EditYouTubeActivity__section">
        <div class="EditYouTubeActivity__meta">
          <span class="EditYouTubeActivity__metaSpinner" aria-hidden="true"></span>
          <span class="EditYouTubeActivity__metaLabel">Loading video info...</span>
        </div>
      </div>

      <div v-if="props.showPreview" class="EditYouTubeActivity__section">
        <BoxButton
          label="Preview"
          :icon="EYE"
          icon-position="right"
          variant="secondary"
          size="lg"
          full-width
          :icon-opacity="0.5"
          @click="emit('preview')"
        />
      </div>

      <div class="EditYouTubeActivity__bottomSpacer"></div>
    </div>
  </div>
</template>
