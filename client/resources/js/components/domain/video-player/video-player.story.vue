<script setup lang="ts">
import VideoPlayer from './video-player.vue'
</script>

<template>
  <Story title="Domain/VideoPlayer" :layout="{ type: 'single', iframe: false }">
    <Variant title="Idle (no src)">
      <div style="width: 440px; height: 300px; background: #0d101a; padding: 16px;">
        <VideoPlayer src="" style="height: 268px;" />
      </div>
    </Variant>
    <Variant title="With poster">
      <div style="width: 440px; height: 300px; background: #0d101a; padding: 16px;">
        <VideoPlayer
          src="https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
          poster="https://picsum.photos/440/268"
          style="height: 268px;"
          :on-ready="(d) => console.log('ready', d)"
          :on-play="() => console.log('play')"
          :on-pause="() => console.log('pause')"
          :on-ended="() => console.log('ended')"
        />
      </div>
    </Variant>
  </Story>
</template>
