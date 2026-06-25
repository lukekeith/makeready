<script setup lang="ts">
import Image from './image.vue'

const sample = 'https://picsum.photos/seed/makeready/600/400'
const portrait = 'https://picsum.photos/seed/portrait/600/800'
</script>

<template>
  <Story title="Primitives/Image" :layout="{ type: 'grid', width: 320 }">
    <Variant title="Cover · Square">
      <Image :src="sample" alt="Sample" fit="Cover" ratio="Square" rounded />
    </Variant>

    <Variant title="Contain · 3:2">
      <Image :src="sample" alt="Sample" fit="Contain" ratio="ThreeTwo" />
    </Variant>

    <Variant title="Cover · Portrait">
      <Image :src="portrait" alt="Portrait sample" fit="Cover" ratio="Portrait" rounded />
    </Variant>

    <Variant title="Auto ratio">
      <Image :src="sample" alt="Sample" ratio="Auto" />
    </Variant>

    <Variant title="Error fallback">
      <Image src="https://invalid.example/missing.jpg" alt="Missing image" ratio="Square" rounded />
    </Variant>
  </Story>
</template>
