<script setup lang="ts">
// Pinia is installed globally in histoire.setup.ts, so the toast store inside
// <CopyLinkField> resolves here.
import CopyLinkField from './copy-link-field.vue'

const shortUrl = 'https://makeready.app/i/AB12CD'
const longUrl =
  'https://makeready.app/invite/accept?token=eyJhbGciOiJIUzI1Ni&scope=group&org=northpoint-community-church'
</script>

<template>
  <Story title="Invite/CopyLinkField" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default">
      <CopyLinkField :url="shortUrl" />
    </Variant>

    <Variant title="With label">
      <CopyLinkField label="Invite link" :url="shortUrl" />
    </Variant>

    <Variant title="Long URL (truncates)">
      <CopyLinkField label="Share this link" :url="longUrl" />
    </Variant>
  </Story>
</template>
