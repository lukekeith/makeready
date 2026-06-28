<script setup lang="ts">
// AlphabetScrubber — vertical A–Z navigation rail (web twin of iOS
// Components/Display/AlphabetScrubber.swift). A fixed-width column of
// accent-blue letters, each in a 28×16 box (spacing 2), vertically centered.
//
// Snapshot parity note: the iPhone capture harness renders the scrubber inside
// `.frame(height: 360).padding(16)` (see ViewRegistry.swift), so the full 26-row
// column (466pt of content) is clipped top & bottom by the 360pt frame and
// centered — A/B and Y/Z fall outside the crop. This twin reproduces that exact
// frame: a 360px-tall, overflow-hidden column. The surrounding `.capture-wrap`
// supplies the 16px gutter that the iOS `.padding(16)` adds, so the captured
// height matches (360 + 32 = 392pt → 1176px @3x).
//
// Fields (props):
//   letters  string[]  — the labels to render, top→bottom (default A–Z)
interface Props {
  letters?: string[]
}

const props = withDefaults(defineProps<Props>(), {
  letters: () => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''),
})
</script>

<template>
  <div class="AlphabetScrubber">
    <span
      v-for="(letter, i) in props.letters"
      :key="`${letter}-${i}`"
      class="AlphabetScrubber__letter"
      >{{ letter }}</span
    >
  </div>
</template>
