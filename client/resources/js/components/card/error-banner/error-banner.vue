<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// ErrorBanner — twin of iOS Components/Feedback/ErrorBanner.swift (the `ErrorBanner`
// struct, the pure-presentation banner; ErrorBannerHost is its animation wrapper and
// is not part of the snapshot). The top error banner that surfaces failures of an
// action the user just took.
//
// iOS layout (HStack spacing 12) reproduced 1:1:
//   icon     exclamationmark.triangle.fill, Typography.s14, white
//   message  Typography.s14Semibold, white, leading, .lineLimit(2)
//   retry    (only when a retry closure exists) a Capsule pill, white@0.2 fill,
//            arrow.clockwise (s12Semibold) + "Retry" (s13Semibold), white,
//            .padding(.horizontal 10).padding(.vertical 6), inner HStack spacing 4
//   banner   .padding(.horizontal 16).padding(.vertical 12), Color.error fill,
//            RoundedRectangle(cornerRadius 12)
//   chrome   .padding(.horizontal 16).padding(.top 8) around the red banner
//
// The triangle and the retry arrow are fixed chrome (never vary by data), so they
// live inline here rather than coming through the adapter as semantic icons — the
// only variant data is `message` + `hasRetry`.
interface Props {
  message?: string
  hasRetry?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  message: '',
  hasRetry: false,
})

const classes = computed(() => classnames('ErrorBanner', props.class))
</script>

<template>
  <div :class="classes">
    <div class="ErrorBanner__banner">
      <!-- exclamationmark.triangle.fill: white filled triangle with the bang
           knocked out (showing the red banner through it). -->
      <span class="ErrorBanner__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none">
          <path
            d="M10.27 3.86 1.6 18.5a2 2 0 0 0 1.72 3h17.36a2 2 0 0 0 1.72-3L13.73 3.86a2 2 0 0 0-3.46 0Z"
            fill="currentColor"
          />
          <path
            d="M12 9.2a1 1 0 0 0-1 1v4a1 1 0 0 0 2 0v-4a1 1 0 0 0-1-1Z"
            class="ErrorBanner__icon-knockout"
          />
          <circle cx="12" cy="17.4" r="1.15" class="ErrorBanner__icon-knockout" />
        </svg>
      </span>

      <p class="ErrorBanner__message">{{ message }}</p>

      <button v-if="hasRetry" type="button" class="ErrorBanner__retry">
        <span class="ErrorBanner__retry-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
               stroke-linecap="round" stroke-linejoin="round">
            <path d="M20 11.5a8 8 0 1 1-2.3-5.4" />
            <path d="M20 3.5v4h-4" />
          </svg>
        </span>
        <span class="ErrorBanner__retry-label">Retry</span>
      </button>
    </div>
  </div>
</template>
