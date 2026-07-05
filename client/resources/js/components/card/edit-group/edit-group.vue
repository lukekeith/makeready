<script setup lang="ts">
// EditGroup — twin of the INLINE `editGroupContent` form in iPhone
// GroupHomePage.swift:381-529 (NOT EditGroupPage.swift), the .groupHome
// modal's LEADING-edge SlideStack detail.
//
// Composes the existing input twins exactly as iOS does (ScrollView
// VStack(spacing:20), every row pad-h16 EXCEPT the full-bleed cover):
//   PageTitle "Edit Group" / chevron.left / "Done" (Done NEVER shows a saving
//   state — iOS slides back optimistically and PATCHes fire-and-forget)
//   → CoverImagePicker (.display: pencil top-right, name+description overlay)
//   → TextInput floating "Group name"
//   → MultilineTextInput "Describe the purpose of this group" (minH 130)
//   → ONE white@0.1 r10 card of three bare ToggleControls (iOS ToggleGroup,
//     NO dividers at this call site — exact iOS strings)
//   → AgeRangeInput "Age range"
//   → MenuInput "Max members" (wheel; options Unlimited + 1…100)
//   → 40px bottom spacer
//
// `interactive` gates all input behavior; the compare harness never sets it,
// so the captured rendering is the settled, unfocused form.
import { ref } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import CoverImagePicker from '../cover-image-picker/cover-image-picker.vue'
import TextInput from '../text-input/text-input.vue'
import MultilineTextInput from '../multiline-text-input/multiline-text-input.vue'
import ToggleControl from '../toggle-control/toggle-control.vue'
import AgeRangeInput from '../age-range-input/age-range-input.vue'
import MenuInput from '../menu-input/menu-input.vue'

interface Props {
  groupName?: string
  groupDescription?: string
  coverUrl?: string
  hasImage?: boolean
  isPrivate?: boolean
  allowInvites?: boolean
  memberDirectory?: boolean
  ageMin?: string
  ageMax?: string
  /** Display string — "Unlimited" or "1"…"100" (iOS MenuInput options). */
  maxMembers?: string
  interactive?: boolean
  uploadingCover?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  groupName: '',
  groupDescription: '',
  coverUrl: '',
  hasImage: false,
  isPrivate: false,
  allowInvites: false,
  memberDirectory: false,
  ageMin: '18',
  ageMax: '34',
  maxMembers: 'Unlimited',
  interactive: false,
  uploadingCover: false,
})

const emit = defineEmits<{
  back: []
  done: []
  'update:groupName': [value: string]
  'update:groupDescription': [value: string]
  toggle: [key: 'isPrivate' | 'allowInvites' | 'memberDirectory']
  'update:ageMin': [value: string]
  'update:ageMax': [value: string]
  'update:maxMembers': [value: string]
  coverPick: [file: File]
}>()

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'

// iOS MenuInput options: ["Unlimited", "1"…"100"].
const MAX_MEMBER_OPTIONS = ['Unlimited', ...Array.from({ length: 100 }, (_, i) => String(i + 1))]

// Exact iOS toggle strings (GroupHomePage.swift:436-464).
const TOGGLES = [
  {
    key: 'isPrivate' as const,
    title: 'Private',
    description: 'Only members can see members and their activity in the group.',
  },
  {
    key: 'allowInvites' as const,
    title: 'Allow members to send invites',
    description: 'Enable this option to send invites from their mobile web portal',
  },
  {
    key: 'memberDirectory' as const,
    title: 'Member directory',
    description: 'Allow members to see other members in the group',
  },
]

function toggleValue(key: (typeof TOGGLES)[number]['key']): boolean {
  return { isPrivate: props.isPrivate, allowInvites: props.allowInvites, memberDirectory: props.memberDirectory }[key]
}

// Cover pick (production): whole cover is the tap target, hidden file input.
const fileInput = ref<HTMLInputElement | null>(null)

function onCoverClick(): void {
  if (props.interactive) fileInput.value?.click()
}

function onFileChange(e: Event): void {
  const file = (e.target as HTMLInputElement).files?.[0]
  ;(e.target as HTMLInputElement).value = ''
  if (file) emit('coverPick', file)
}
</script>

<template>
  <div class="EditGroup">
    <PageTitle
      class="EditGroup__title"
      title="Edit Group"
      :left-icon="BACK_CHEVRON"
      right-link="Done"
      @left="emit('back')"
      @right="emit('done')"
    />

    <div class="EditGroup__scroll">
      <!-- Cover (iOS mode .display: pencil top-right; full-bleed) -->
      <div
        class="EditGroup__cover"
        :role="interactive ? 'button' : undefined"
        :tabindex="interactive ? 0 : undefined"
        @click="onCoverClick"
        @keydown.enter.prevent="onCoverClick"
      >
        <CoverImagePicker
          mode="display"
          :program-name="groupName"
          :program-description="groupDescription"
          :cover-url="coverUrl || undefined"
          :has-image="hasImage || !!coverUrl"
        />
        <div v-if="uploadingCover" class="EditGroup__coverBusy">
          <span class="EditGroup__spinner" aria-label="Uploading"></span>
        </div>
        <input
          v-if="interactive"
          ref="fileInput"
          class="EditGroup__file"
          type="file"
          accept="image/*"
          @change="onFileChange"
        />
      </div>

      <!-- Group name -->
      <div class="EditGroup__section">
        <TextInput
          :interactive="interactive"
          floating-label="Group name"
          :text="groupName"
          @update:text="emit('update:groupName', $event)"
        />
      </div>

      <!-- Description -->
      <div class="EditGroup__section">
        <MultilineTextInput
          :interactive="interactive"
          placeholder="Describe the purpose of this group"
          :text="groupDescription"
          @update:text="emit('update:groupDescription', $event)"
        />
      </div>

      <!-- Privacy toggles — ONE ToggleGroup card, bare rows, NO dividers -->
      <div class="EditGroup__section">
        <div class="EditGroup__toggles">
          <ToggleControl
            v-for="t in TOGGLES"
            :key="t.key"
            bare
            :title="t.title"
            :description="t.description"
            :is-on="toggleValue(t.key)"
            @toggle="interactive && emit('toggle', t.key)"
          />
        </div>
      </div>

      <!-- Age range -->
      <div class="EditGroup__section">
        <AgeRangeInput
          label="Age range"
          :min-age="ageMin"
          :max-age="ageMax"
          :interactive="interactive"
          @update:min-age="emit('update:ageMin', $event)"
          @update:max-age="emit('update:ageMax', $event)"
        />
      </div>

      <!-- Max members -->
      <div class="EditGroup__section">
        <MenuInput
          label="Max members"
          picker-style="wheel"
          :options="MAX_MEMBER_OPTIONS"
          :selected-value="maxMembers"
          :interactive="interactive"
          @update:selected-value="emit('update:maxMembers', $event)"
        />
      </div>

      <!-- iOS trailing Spacer(40) -->
      <div class="EditGroup__bottom-spacer" />
    </div>
  </div>
</template>
