/**
 * Adapter: TextInput (component comparison, two-sided twin).
 *
 * Projects one canonical text-input description into:
 *   - toClient → text-input.vue via the ComponentCapture island
 *   - toIphone → TextInput.swift via the component.TextInput case
 *               (TextInput wrapped in a FieldGroup, .padding(16) — unchanged
 *                from today)
 *
 * The fixture's `shared` block carries one of `{ placeholder | label | floatingLabel }`
 * plus `{ icon?, inputType, text }`. The iPhone derives its style from which label
 * field is set and renders the SF symbol named in `icon`; the web twin renders
 * inline SVG, so this adapter maps the labeled variants' `icon` SF-symbol name → an
 * SF-symbol-like SVG and forwards the rest unchanged. `inputType` only affects
 * keyboard/formatting on iOS (the captured text is already in display form), so it
 * is forwarded to iPhone and ignored by the web twin.
 */

// SF-symbol-like inline SVGs for the web twin, brand-purple via currentColor.
const ICONS = {
  // person.fill — head circle + rounded shoulders (Name).
  'person.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="7.4" r="4.3"/><path d="M12 13.3c-4.3 0-7.4 2.4-7.4 5.4 0 1.05.75 1.6 2 1.6h10.8c1.25 0 2-.55 2-1.6 0-3-3.1-5.4-7.4-5.4z"/></svg>',
  // envelope.fill — SOLID envelope body with the flap fold cut into it (Email).
  'envelope.fill':
    '<svg viewBox="0 0 24 24"><path fill="currentColor" d="M4.4 5.2h15.2c1.55 0 2.4.85 2.4 2.4v8.8c0 1.55-.85 2.4-2.4 2.4H4.4c-1.55 0-2.4-.85-2.4-2.4V7.6c0-1.55.85-2.4 2.4-2.4z"/><path fill="none" stroke="rgba(0,0,0,0.5)" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" d="M3 7.6 12 13.3l9-5.7"/></svg>',
  // phone.fill — solid handset (Phone).
  'phone.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.7 3.4c-.62-.6-1.62-.58-2.2.05l-1 1.05c-1 1.05-1.2 2.6-.55 3.95 2.1 4.45 5.7 8.05 10.15 10.15 1.35.65 2.9.45 3.95-.55l1.05-1c.63-.58.65-1.58.05-2.2l-2.5-2.6c-.6-.62-1.6-.64-2.22-.04l-1.02 1c-1.75-1-3.2-2.45-4.2-4.2l1-1.02c.6-.62.58-1.62-.04-2.22z"/></svg>',
  // location.fill — the iOS navigation arrow: a NE-pointing filled arrowhead with
  // a center notch (an up-arrow rotated 45° clockwise), NOT a map pin (City).
  'location.fill':
    '<svg viewBox="0 0 24 24"><path fill="currentColor" transform="rotate(45 12 12)" d="M12 2.5 18.6 19.6 12 15.5 5.4 19.6Z"/></svg>',
};

export default {
  toClient(shared = {}) {
    const {
      placeholder = '',
      label = '',
      floatingLabel = '',
      icon = '',
      text = '',
    } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (FieldGroup card + 16px gutters),
      // matching the iPhone snapshot (ViewRegistry wraps it in .padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'TextInput',
        componentProps: {
          placeholder,
          label,
          floatingLabel,
          icon: icon ? (ICONS[icon] ?? '') : '',
          text,
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged (iOS derives style + SF symbol from it).
    return {
      platform: 'iphone',
      view: 'component.TextInput',
      state: { component: shared },
    };
  },
};
