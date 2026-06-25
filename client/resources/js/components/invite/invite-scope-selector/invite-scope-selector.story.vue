<script setup lang="ts">
import { ref } from 'vue'
import InviteScopeSelector from './invite-scope-selector.vue'

type Scope = { type: 'program' | 'lesson'; id: string | number }

const programs = [
  {
    id: 'romans',
    title: 'Romans in 30 Days',
    lessons: [
      { id: 'rom-1', title: 'The Gospel of God', dayLabel: 'Day 1' },
      { id: 'rom-2', title: 'Righteous Judgment', dayLabel: 'Day 2' },
      { id: 'rom-4', title: 'Faith of Abraham', dayLabel: 'Day 4' },
    ],
  },
  {
    id: 'james',
    title: 'James: Faith That Works',
    lessons: [
      { id: 'jas-1', title: 'Trials and Wisdom', dayLabel: 'Day 1' },
      { id: 'jas-2', title: 'Faith and Deeds', dayLabel: 'Day 2' },
    ],
  },
]

const scope = ref<Scope | null>(null)
const presetProgram = ref<Scope | null>({ type: 'program', id: 'romans' })
const presetLesson = ref<Scope | null>({ type: 'lesson', id: 'rom-4' })
</script>

<template>
  <Story title="Invite/InviteScopeSelector" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Nothing selected">
      <InviteScopeSelector v-model="scope" :programs="programs" />
    </Variant>
    <Variant title="Program selected">
      <InviteScopeSelector v-model="presetProgram" :programs="programs" />
    </Variant>
    <Variant title="Lesson selected">
      <InviteScopeSelector v-model="presetLesson" :programs="programs" />
    </Variant>
  </Story>
</template>
