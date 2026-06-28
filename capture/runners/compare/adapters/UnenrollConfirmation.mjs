/**
 * Adapter: UnenrollConfirmation (component comparison).
 *
 * Projects one canonical unenroll-confirmation description into:
 *   - toClient → card/unenroll-confirmation/unenroll-confirmation.vue via the
 *                ComponentCapture island
 *   - toIphone → component.UnenrollConfirmation ViewRegistry case
 *               (Components/Feedback/UnenrollConfirmation.swift)
 *
 * UnenrollConfirmation is not a standalone view on iOS: its `present(...)` builds
 * a ConfirmationOverlay (style .warning, "Done" button, processingMessage
 * "Processing unenrollment") whose message comes from
 * `successMessage(option:programName:)`. The capture ViewRegistry renders exactly
 * that overlay; the Vue twin mirrors it and derives the message + warning glyph
 * from the same { option, programName } inputs.
 *
 * ⚠️ Parity note: in the isolated /compare snapshot the iPhone reference is BLANK
 * (just the dark app canvas). ConfirmationOverlay enters at contentOpacity 0 /
 * blurOpacity 0 and fades/scales in only via `.onAppear`, so the SwiftUI snapshot
 * captures the pre-animation frame. The Vue twin renders the overlay at its final
 * (visible) state — the emptiness on iOS is an accepted platform artifact (same as
 * ConfirmationOverlay / DialogOverlay).
 *
 * The `shared` block is { option, programName, isProcessing }. The iPhone side
 * receives it unchanged. The warning glyph (SF Symbol exclamationmark.triangle) is
 * intrinsic chrome — it never varies by data — so it's resolved to an inline SVG
 * here for the web side (same semantic-icon mapping as ConfirmationOverlay).
 */

// iOS ConfirmationOverlayStyle.warning.iconName = "exclamationmark.triangle" →
// web inline SVG (rendered in Color.appBackground over the #ffaa00 circle).
const WARNING_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.8L22 20.2H2L12 3.8z"/><path d="M12 10v4.4"/><circle cx="12" cy="17.2" r="1" fill="currentColor" stroke="none"/></svg>';

export default {
  toClient(shared) {
    const {
      option = 'fullRemoval',
      programName = '',
      isProcessing = false,
    } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot framing (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'UnenrollConfirmation',
        componentProps: {
          option,
          programName,
          isProcessing: isProcessing === true,
          icon: WARNING_ICON,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.UnenrollConfirmation',
      state: { component: shared },
    };
  },
};
