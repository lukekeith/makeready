<script lang="ts">
import { cva } from '../../../util/cva'

// QRCodeDisplay — presentational QR panel. The `src` is a data-URL (or image
// URL) of an ALREADY-GENERATED QR code; it comes from the server endpoint
// `/api/qrcode/generate` (brand colour #6C47FF). This component only DISPLAYS
// that image — it never generates a QR code itself.
//
// Styles are global via app.scss; this component only emits classes. CVA size
// keys map 1:1 to the .QRCodeDisplay--size-* SCSS modifiers (which set the fixed
// 160/240/320px panel — the allowed QR exception to tokens-only).
export const QRCodeDisplayCva = cva('QRCodeDisplay', {
  variants: {
    size: {
      Sm: 'QRCodeDisplay--size-sm',
      Md: 'QRCodeDisplay--size-md',
      Lg: 'QRCodeDisplay--size-lg',
    },
  },
  defaultVariants: {
    size: 'Md',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  /** Data-URL / image URL of the generated QR (from /api/qrcode/generate). */
  src?: string
  size?: keyof typeof QRCodeDisplayCva.size
  caption?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => QRCodeDisplayCva.defaults?.size as keyof typeof QRCodeDisplayCva.size,
})

const classes = computed(() =>
  classnames(QRCodeDisplayCva.variants({ size: props.size }), props.class)
)
</script>

<template>
  <div :class="classes">
    <div class="QRCodeDisplay__panel">
      <img
        v-if="src"
        class="QRCodeDisplay__img"
        :src="src"
        alt="QR code"
      />
      <div v-else class="QRCodeDisplay__placeholder" aria-hidden="true" />
    </div>
    <p v-if="caption" class="QRCodeDisplay__caption">{{ caption }}</p>
  </div>
</template>
