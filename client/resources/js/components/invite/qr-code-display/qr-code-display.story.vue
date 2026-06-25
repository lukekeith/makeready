<script setup lang="ts">
import QRCodeDisplay from './qr-code-display.vue'

// Inline SVG data-URL standing in for a server-generated QR (brand #6C47FF).
// In production `src` is the data-URL returned by /api/qrcode/generate.
const sampleQr =
  'data:image/svg+xml;utf8,' +
  encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 9 9" shape-rendering="crispEdges">
      <rect width="9" height="9" fill="#ffffff"/>
      <g fill="#6C47FF">
        <rect x="0" y="0" width="3" height="3"/><rect x="1" y="1" width="1" height="1" fill="#fff"/>
        <rect x="6" y="0" width="3" height="3"/><rect x="7" y="1" width="1" height="1" fill="#fff"/>
        <rect x="0" y="6" width="3" height="3"/><rect x="1" y="7" width="1" height="1" fill="#fff"/>
        <rect x="4" y="0" width="1" height="1"/><rect x="4" y="2" width="1" height="1"/>
        <rect x="0" y="4" width="1" height="1"/><rect x="2" y="4" width="1" height="1"/>
        <rect x="4" y="4" width="1" height="1"/><rect x="6" y="4" width="1" height="1"/>
        <rect x="8" y="4" width="1" height="1"/><rect x="4" y="6" width="1" height="1"/>
        <rect x="6" y="6" width="1" height="1"/><rect x="8" y="8" width="1" height="1"/>
        <rect x="5" y="5" width="1" height="1"/><rect x="7" y="7" width="1" height="1"/>
      </g>
    </svg>`
  )
</script>

<template>
  <Story title="Invite/QRCodeDisplay" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default (Md)">
      <QRCodeDisplay :src="sampleQr" />
    </Variant>

    <Variant title="With caption">
      <QRCodeDisplay :src="sampleQr" caption="Scan to join the group" />
    </Variant>

    <Variant title="Sizes">
      <div class="col">
        <QRCodeDisplay :src="sampleQr" size="Sm" caption="Sm — 160" />
        <QRCodeDisplay :src="sampleQr" size="Md" caption="Md — 240" />
        <QRCodeDisplay :src="sampleQr" size="Lg" caption="Lg — 320" />
      </div>
    </Variant>

    <Variant title="Placeholder (no src)">
      <QRCodeDisplay size="Md" caption="Generating QR…" />
    </Variant>
  </Story>
</template>

<style scoped>
.col { display: flex; flex-direction: column; gap: var(--space-lg); padding: var(--space-md); }
</style>
