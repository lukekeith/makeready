/**
 * Adapter: GroupActionButton (component comparison).
 *
 * Projects one canonical group-action-button description into:
 *   - toClient → group-action-button.vue via the ComponentCapture island
 *   - toIphone → GroupActionButton.swift via the component.GroupActionButton case
 *
 * The iPhone takes an SF symbol name in `icon`; the web twin renders inline SVG,
 * so this adapter maps each semantic SF symbol → an SF-symbol-like filled SVG
 * for the client while forwarding the raw symbol name to iPhone unchanged.
 */
const WEB_ICONS = {
  'video.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 6.5h9A2.5 2.5 0 0 1 15.5 9v6A2.5 2.5 0 0 1 13 17.5H4A2.5 2.5 0 0 1 1.5 15V9A2.5 2.5 0 0 1 4 6.5zM17 9.6l4.2-2.6c.5-.3 1.3-.06 1.3.6v8.8c0 .66-.8.9-1.3.6L17 14.4z"/></svg>',
  'message.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 3C6.5 3 2 6.7 2 11.2c0 2.6 1.5 4.9 3.8 6.4-.2 1-.8 2.3-1.6 3.2-.22.26.02.66.36.56 1.9-.5 3.4-1.2 4.5-1.9.9.2 1.9.3 2.9.3 5.5 0 10-3.7 10-8.6S17.5 3 12 3z"/></svg>',
  'person.2.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="8.8" cy="7.4" r="3.2"/><path d="M8.8 11.6c-3.1 0-5.6 1.9-5.6 4.4 0 .9.7 1.5 1.6 1.5h8c.9 0 1.6-.6 1.6-1.5 0-2.5-2.5-4.4-5.6-4.4z"/><circle cx="16.6" cy="8" r="2.7"/><path d="M16.6 11.8c-.9 0-1.6.16-2.3.45 1.2 1.05 1.95 2.5 1.95 4.1 0 .3-.05.6-.15.9h3.9c.85 0 1.5-.55 1.5-1.4 0-2.3-2.2-4.05-4.9-4.05z"/></svg>',
  'photo.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd"><path d="M4 4.5h16A2.5 2.5 0 0 1 22.5 7v10a2.5 2.5 0 0 1-2.5 2.5H4A2.5 2.5 0 0 1 1.5 17V7A2.5 2.5 0 0 1 4 4.5zm2.9 3.4a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6zM3.5 16.6l4.9-5.1 2.7 2.9 4-4.4 5.4 6.6z"/></svg>',
};

export default {
  toClient(shared) {
    const { label, icon } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'GroupActionButton',
        componentProps: {
          label: label ?? '',
          icon: WEB_ICONS[icon] ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    // Forward the canonical shape unchanged (SF symbol name stays in `icon`).
    return {
      platform: 'iphone',
      view: 'component.GroupActionButton',
      state: { component: shared },
    };
  },
};
