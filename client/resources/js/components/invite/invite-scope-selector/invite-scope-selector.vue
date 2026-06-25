<script setup lang="ts">
import { computed, ref } from 'vue'
import { classnames } from '../../../util/classnames'
import Radio from '../../primitive/radio/radio.vue'

// InviteScopeSelector — invite domain. Choose the invite scope: an entire study
// program OR a single lesson within it. A list of programs; selecting a program
// row picks scope { type: 'program', id }. Expanding a program reveals its
// lessons; selecting a lesson row picks { type: 'lesson', id }. Radio drives
// selection; the selected row gets a brand highlight. No CVA — single block
// with state modifiers in scss.

interface Lesson {
  id: string | number
  title: string
  dayLabel?: string
}

interface Program {
  id: string | number
  title: string
  lessons: Lesson[]
}

type Scope = { type: 'program' | 'lesson'; id: string | number }

interface Props {
  programs: Program[]
  modelValue?: Scope | null
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: null,
})

const emit = defineEmits<{ 'update:modelValue': [value: Scope] }>()

const expanded = ref<Set<string | number>>(new Set())

const isExpanded = (id: string | number) => expanded.value.has(id)

const toggle = (id: string | number) => {
  const next = new Set(expanded.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  expanded.value = next
}

// Stable radio value strings so program and lesson ids never collide.
const programValue = (id: string | number) => `program:${id}`
const lessonValue = (id: string | number) => `lesson:${id}`

const selectedValue = computed(() => {
  const v = props.modelValue
  if (!v) return ''
  return v.type === 'program' ? programValue(v.id) : lessonValue(v.id)
})

const classes = computed(() => classnames('InviteScopeSelector', props.class))

const selectProgram = (id: string | number) => {
  emit('update:modelValue', { type: 'program', id })
}

const selectLesson = (id: string | number) => {
  emit('update:modelValue', { type: 'lesson', id })
}
</script>

<template>
  <div :class="classes" role="radiogroup">
    <div
      v-for="program in programs"
      :key="program.id"
      class="InviteScopeSelector__program"
    >
      <div
        :class="classnames(
          'InviteScopeSelector__row',
          modelValue?.type === 'program' && modelValue?.id === program.id && 'InviteScopeSelector__row--selected'
        )"
      >
        <Radio
          class="InviteScopeSelector__radio"
          :model-value="selectedValue"
          :value="programValue(program.id)"
          name="invite-scope"
          @update:model-value="selectProgram(program.id)"
        />
        <button
          type="button"
          class="InviteScopeSelector__label"
          @click="selectProgram(program.id)"
        >
          <span class="InviteScopeSelector__title">{{ program.title }}</span>
          <span class="InviteScopeSelector__meta">Entire program</span>
        </button>
        <button
          v-if="program.lessons.length"
          type="button"
          :class="classnames(
            'InviteScopeSelector__toggle',
            isExpanded(program.id) && 'InviteScopeSelector__toggle--open'
          )"
          :aria-expanded="isExpanded(program.id)"
          :aria-label="isExpanded(program.id) ? 'Collapse lessons' : 'Expand lessons'"
          @click="toggle(program.id)"
        >
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M8 10l4 4 4-4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </button>
      </div>

      <div v-if="isExpanded(program.id)" class="InviteScopeSelector__lessons">
        <div
          v-for="lesson in program.lessons"
          :key="lesson.id"
          :class="classnames(
            'InviteScopeSelector__row',
            'InviteScopeSelector__row--lesson',
            modelValue?.type === 'lesson' && modelValue?.id === lesson.id && 'InviteScopeSelector__row--selected'
          )"
        >
          <Radio
            class="InviteScopeSelector__radio"
            size="Sm"
            :model-value="selectedValue"
            :value="lessonValue(lesson.id)"
            name="invite-scope"
            @update:model-value="selectLesson(lesson.id)"
          />
          <button
            type="button"
            class="InviteScopeSelector__label"
            @click="selectLesson(lesson.id)"
          >
            <span class="InviteScopeSelector__title">{{ lesson.title }}</span>
            <span v-if="lesson.dayLabel" class="InviteScopeSelector__meta">{{ lesson.dayLabel }}</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
