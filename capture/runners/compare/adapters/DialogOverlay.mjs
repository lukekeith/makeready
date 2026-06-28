/**
 * Adapter: DialogOverlay (component comparison).
 *
 * Projects one canonical dialog description into:
 *   - toClient → card/dialog-overlay/dialog-overlay.vue via the ComponentCapture island
 *   - toIphone → component.DialogOverlay ViewRegistry case
 *               (Components/Display/DialogOverlay.swift)
 *
 * ⚠️ Parity note: in the isolated /compare snapshot the iPhone reference is
 * EMPTY. DialogOverlay enters at `visible = false` (opacity 0, scaleEffect 0.85)
 * and fades/scales in only via `.onAppear { withAnimation(...) }`; the SwiftUI
 * snapshot captures the pre-animation frame, so the dialog never appears. The
 * Vue twin renders the dialog at its final (visible) state so the web side shows
 * the real component — the emptiness on iOS is an accepted platform artifact.
 *
 * The shared block IS the dialog prop bag (isPresented + optional title/message +
 * buttons[{ label, style }]); both adapters forward it directly. The iPhone side
 * receives it unchanged (decoded loosely in ViewRegistry); the client side maps
 * it to the Vue twin's props (isPresented is dropped — the twin always renders).
 */
export default {
  toClient(shared) {
    const { title, message, buttons = [] } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot framing (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'DialogOverlay',
        componentProps: {
          title: title ?? '',
          message: message ?? '',
          buttons: buttons.map((b) => ({
            label: b.label,
            style: b.style ?? 'primary',
          })),
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.DialogOverlay',
      state: { component: shared },
    };
  },
};
