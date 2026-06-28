<script setup lang="ts">
import CardVideo from './card-video.vue'
import CardVideoSkeleton from './card-video-skeleton.vue'

const eye =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>'
const clock =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>'
const share =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16V4M8 8l4-4 4 4"/><path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>'
const play =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7L8 5Z"/></svg>'
</script>

<template>
  <Story title="Cards/CardVideo" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Photo (confirmed)">
      <CardVideo
        title="Sunday Sermon: Faith in Action"
        description="Sermons"
        status="confirmed"
        :image-style="{ kind: 'photo' }"
        :metadata="[
          { icon: eye, value: '1.2K' },
          { icon: clock, value: '5 mins ago' },
          { icon: share, value: '45' },
        ]"
      />
    </Variant>

    <Variant title="New (select video)">
      <CardVideo
        title="VIDEO"
        description="Select video"
        status="new"
        :image-style="{ kind: 'icon', icon: play }"
      />
    </Variant>

    <Variant title="Skeleton">
      <CardVideoSkeleton />
    </Variant>
  </Story>
</template>
