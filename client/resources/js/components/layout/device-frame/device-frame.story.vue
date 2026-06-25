<script setup lang="ts">
import DeviceFrame from './device-frame.vue'
</script>

<template>
  <Story title="Foundations/Device Frame" :layout="{ type: 'grid', width: 480 }">
    <Variant title="Default (390)">
      <DeviceFrame>
        <div class="DeviceFrameDemo">
          <h2>Screen content</h2>
          <p>Wrap page stories in <code>&lt;DeviceFrame&gt;</code> to test at a real phone width on the app canvas.</p>
        </div>
      </DeviceFrame>
    </Variant>

    <Variant title="iPhone SE (320)">
      <DeviceFrame size="Se">
        <div class="DeviceFrameDemo">
          <h2>Small phone</h2>
          <p>At 320 the <code>@media (max-width: 360px)</code> token shrink applies — spacing and type tighten automatically.</p>
        </div>
      </DeviceFrame>
    </Variant>

    <Variant title="Pro Max (430)">
      <DeviceFrame size="Lg">
        <div class="DeviceFrameDemo">
          <h2>Large phone</h2>
          <p>Widest target.</p>
        </div>
      </DeviceFrame>
    </Variant>

    <Variant title="Safe-area guides">
      <DeviceFrame :safe-areas="true">
        <div class="DeviceFrameDemo">
          <h2>Safe areas</h2>
          <p>The tinted bands show the top/bottom inset regions layouts must pad for.</p>
        </div>
      </DeviceFrame>
    </Variant>

    <Variant title="No chrome (bare canvas)">
      <DeviceFrame :chrome="false">
        <div class="DeviceFrameDemo">
          <h2>Bare canvas</h2>
          <p>Frame without bezel/notch — for embedding in larger composites.</p>
        </div>
      </DeviceFrame>
    </Variant>
  </Story>
</template>

<style>
.DeviceFrameDemo {
  padding: var(--space-xl) var(--page-pad-x);
}
.DeviceFrameDemo h2 {
  font-size: var(--text-heading);
  line-height: var(--leading-heading);
  font-weight: var(--font-weight-bold);
  color: var(--fg-primary);
  margin-bottom: var(--space-sm);
}
.DeviceFrameDemo p {
  font-size: var(--text-sm);
  line-height: var(--leading-sm);
  color: var(--fg-secondary);
}
.DeviceFrameDemo code {
  color: var(--fg-accent);
  font-family: var(--font-serif, monospace);
}
</style>
