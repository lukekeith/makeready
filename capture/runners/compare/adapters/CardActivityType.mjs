/**
 * Adapter: CardActivityType (component comparison).
 *
 * Projects one canonical activity-type description into:
 *   - toClient → card-activity-type.vue via the ComponentCapture island
 *   - toIphone → CardActivityType.swift via the component.CardActivityType case
 *
 * `imageStyle` is the iOS image enum as data ({ kind, systemName, background } |
 * absent when a `coverUrl` photo is used). The iPhone consumes it directly; the
 * web adapter maps the SF Symbol to inline SVG and forwards the named background.
 */

// SF Symbol → inline SVG (24×24, currentColor → white). Filled, like SF .fill.
const WEB_ICONS = {
  'book.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11.25 6.6C9.7 5.45 7.5 4.85 5.1 4.85c-.85 0-1.7.08-2.45.24-.38.08-.65.42-.65.81v10.5c0 .53.49.92 1 .8.66-.14 1.39-.2 2.1-.2 2 0 4 .52 5.35 1.55a.5.5 0 0 0 .8-.4V7a.5.5 0 0 0-.0-.4Z"/><path d="M12.75 6.6C14.3 5.45 16.5 4.85 18.9 4.85c.85 0 1.7.08 2.45.24.38.08.65.42.65.81v10.5c0 .53-.49.92-1 .8-.66-.14-1.39-.2-2.1-.2-2 0-4 .52-5.35 1.55a.5.5 0 0 1-.8-.4V7a.5.5 0 0 1 .0-.4Z"/></svg>',
};

export default {
  toClient(shared) {
    const { mode, title, description, imageStyle, coverUrl, available } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardActivityType',
        componentProps: {
          mode: mode ?? 'list',
          title: title ?? '',
          description: description ?? '',
          coverUrl: coverUrl ?? '',
          icon: imageStyle?.systemName ? WEB_ICONS[imageStyle.systemName] ?? '' : '',
          background: imageStyle?.background ?? 'purple',
          available: available ?? true,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardActivityType',
      state: { component: shared ?? {} },
    };
  },
};
