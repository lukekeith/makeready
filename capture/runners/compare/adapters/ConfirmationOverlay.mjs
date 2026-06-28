/**
 * Adapter: ConfirmationOverlay (component comparison).
 *
 * Projects one canonical confirmation-overlay description into:
 *   - toClient → card/confirmation-overlay/confirmation-overlay.vue via the
 *                ComponentCapture island
 *   - toIphone → component.ConfirmationOverlay ViewRegistry case
 *               (Components/Feedback/ConfirmationOverlay.swift)
 *
 * ⚠️ Parity note: in the isolated /compare snapshot the iPhone reference is
 * BLANK (just the dark app canvas). ConfirmationOverlay enters at contentOpacity
 * 0 / blurOpacity 0 and fades/scales in only via `.onAppear`; the SwiftUI
 * snapshot captures the pre-animation frame, so nothing renders. The Vue twin
 * renders the overlay at its final (visible) state so the web side shows the real
 * component — the emptiness on iOS is an accepted platform artifact (same as
 * DialogOverlay).
 *
 * The `shared` block is the overlay prop bag: { style, message, buttonLabel,
 * isProcessing, processingMessage }. The iPhone side receives it unchanged; the
 * client side maps it to the Vue twin's props and resolves the style's SF Symbol
 * to an inline SVG (the established semantic-icon mapping pattern).
 */

// iOS ConfirmationOverlayStyle.iconName (SF Symbol) → web inline SVG. The glyph
// renders in Color.appBackground (dark) over the bright style circle.
const WEB_ICONS = {
  // checkmark
  success:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7"/></svg>',
  // xmark
  error:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  // exclamationmark.triangle
  warning:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.8L22 20.2H2L12 3.8z"/><path d="M12 10v4.4"/><circle cx="12" cy="17.2" r="1" fill="currentColor" stroke="none"/></svg>',
  // info.circle
  info:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 11.2v5" stroke-linecap="round"/><circle cx="12" cy="7.8" r="1" fill="currentColor" stroke="none"/></svg>',
};

export default {
  toClient(shared) {
    const {
      style = 'success',
      message = '',
      buttonLabel = '',
      isProcessing = false,
      processingMessage = 'Processing...',
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot framing (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'ConfirmationOverlay',
        componentProps: {
          // `tone`, not `style`: `style` is a Vue-reserved fallthrough attribute
          // and would never reach the component's prop.
          tone: style,
          message,
          buttonLabel,
          isProcessing,
          processingMessage,
          icon: WEB_ICONS[style] ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.ConfirmationOverlay',
      state: { component: shared },
    };
  },
};
