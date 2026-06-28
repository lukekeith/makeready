/**
 * Adapter: LargeTextInput (component comparison, two-sided twin).
 *
 * Projects one canonical large-text-input description into:
 *   - toClient → large-text-input.vue via the ComponentCapture island
 *   - toIphone → LargeTextInput.swift via the component.LargeTextInput case
 *               (LargeTextInput wrapped in a FieldGroup, .padding(16) — unchanged
 *                from today)
 *
 * The fixture's `shared` block carries `{ label, inputType, text }`. The iPhone
 * derives its SF symbol + which side it sits on from `inputType`; the web twin
 * renders inline SVG, so this adapter maps each input type → an SF-symbol-like
 * SVG and the side (currency = leading, phone/email/percentage = trailing;
 * alphanumeric/integer/float = no icon), forwarding the raw `inputType` to iPhone.
 */

// SF-symbol-like inline SVGs for the web twin, white via currentColor.
const ICONS = {
  // dollarsign — S stroke with a vertical bar through it (currency, leading).
  dollarsign:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M16.2 7.4C15.1 6 13.3 5.2 11.5 5.2 9 5.2 7.1 6.5 7.1 8.5c0 2.1 2 2.9 4.5 3.4 2.8.55 5 1.4 5 3.6 0 2.1-2.1 3.5-4.9 3.5-2 0-3.9-.85-5-2.4"/><path d="M11.7 2.6V21.4"/></svg>',
  // percent — two hollow rings joined by a diagonal slash (percentage, trailing).
  percent:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round"><circle cx="6.6" cy="6.6" r="2.9" stroke-width="1.7"/><circle cx="17.4" cy="17.4" r="2.9" stroke-width="1.7"/><path d="M18.6 4.4 5.4 19.6" stroke-width="1.9"/></svg>',
  // envelope.fill — rounded envelope body + flap chevron (email, trailing).
  'envelope.fill':
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><rect x="2.6" y="5" width="18.8" height="14" rx="2.6"/><path d="M3.4 7.2 12 13l8.6-5.8"/></svg>',
  // phone.fill — solid handset (phone, trailing).
  'phone.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.7 3.4c-.62-.6-1.62-.58-2.2.05l-1 1.05c-1 1.05-1.2 2.6-.55 3.95 2.1 4.45 5.7 8.05 10.15 10.15 1.35.65 2.9.45 3.95-.55l1.05-1c.63-.58.65-1.58.05-2.2l-2.5-2.6c-.6-.62-1.6-.64-2.22-.04l-1.02 1c-1.75-1-3.2-2.45-4.2-4.2l1-1.02c.6-.62.58-1.62-.04-2.22z"/></svg>',
};

const ICON_FOR = {
  currency: { name: 'dollarsign', side: 'leading' },
  phone: { name: 'phone.fill', side: 'trailing' },
  email: { name: 'envelope.fill', side: 'trailing' },
  percentage: { name: 'percent', side: 'trailing' },
  // alphanumeric / integer / float → no icon
};

export default {
  toClient(shared = {}) {
    const { label = '', inputType = 'alphanumeric', text = '' } = shared;
    const mapped = ICON_FOR[inputType];
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (FieldGroup card + 16px gutters),
      // matching the iPhone snapshot (ViewRegistry wraps it in .padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'LargeTextInput',
        componentProps: {
          label,
          text,
          icon: mapped ? ICONS[mapped.name] : '',
          iconSide: mapped ? mapped.side : 'trailing',
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged (inputType drives the iOS symbol/side).
    return {
      platform: 'iphone',
      view: 'component.LargeTextInput',
      state: { component: shared },
    };
  },
};
