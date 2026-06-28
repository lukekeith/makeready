<script setup lang="ts">
// CardSpinnerOverlay — small dimming spinner overlay twin
// (iOS Components/Loading/CardSpinnerOverlay.swift). Shown over a card while a
// save/update operation is in flight.
//
// iOS structure: ZStack { Color.black.opacity(0.4); ProgressView()
//   .progressViewStyle(.circular, tint: .white).scaleEffect(0.9) }.cornerRadius(8).
// The overlay has no intrinsic size — in the capture harness (ViewRegistry) it
// is rendered over a 320×140 cardBackground rounded rectangle, so the twin
// reproduces that same host card: a 320×140 surface, a black@40% wash, and a
// centered white circular spinner. No props — the only variant is `default`.
//
// The ProgressView is a live, animating spinner on device; the captured
// snapshot freezes it. The twin renders a static 8-spoke spinner (brightest at
// the top, tapering clockwise) so the screenshot is deterministic.
</script>

<template>
  <div class="CardSpinnerOverlay" aria-hidden="true">
    <!-- iOS Color.black.opacity(0.4) wash over the cardBackground host. -->
    <div class="CardSpinnerOverlay__wash" />

    <!-- iOS ProgressView(.circular, tint .white, scaleEffect 0.9) — frozen static
         spoke spinner so the screenshot is deterministic. -->
    <span class="CardSpinnerOverlay__spinner">
      <svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.6" stroke-linecap="round">
        <line x1="12" y1="4.5" x2="12" y2="8" opacity="1" transform="rotate(0 12 12)" />
        <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.85" transform="rotate(45 12 12)" />
        <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.7" transform="rotate(90 12 12)" />
        <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.6" transform="rotate(135 12 12)" />
        <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.5" transform="rotate(180 12 12)" />
        <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.4" transform="rotate(225 12 12)" />
        <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.3" transform="rotate(270 12 12)" />
        <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.2" transform="rotate(315 12 12)" />
      </svg>
    </span>
  </div>
</template>
