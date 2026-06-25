<script setup lang="ts">
// Pinia is installed globally in histoire.setup.ts, so the toast fallback inside
// <ShareButton> resolves here. In browsers without navigator.share the click
// copies the URL and shows a "Link copied" toast.
import ShareButton from './share-button.vue'

const url = 'https://makeready.app/i/AB12CD'
</script>

<template>
  <Story title="Invite/ShareButton" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default">
      <ShareButton :url="url" />
    </Variant>

    <Variant title="With title + text">
      <ShareButton
        :url="url"
        title="Join my group on MakeReady"
        text="I'd love for you to join our study group."
      />
    </Variant>

    <Variant title="Custom label">
      <ShareButton :url="url" label="Share invite" />
    </Variant>
  </Story>
</template>
