/**
 * Adapter: Avatar (component comparison).
 *
 * Projects one canonical avatar description into:
 *   - toClient → card/avatar/avatar.vue via the ComponentCapture island
 *   - toIphone → component.Avatar ViewRegistry case (Components/Display/Avatar.swift)
 *
 * Photo handling: in the isolated /compare snapshot the iPhone's AsyncImage never
 * resolves the remote photo, so every Photo* variant falls back to its initials
 * gradient. To match that reference exactly the client side OMITS the imageURL —
 * the Vue twin then renders the same initials gradient (or, with no initials, the
 * person-icon fallback). The iPhone side still receives the full shared block
 * unchanged (its snapshot does the fallback itself).
 *
 * The person.fill icon fallback is semantic on iOS (SF Symbol); the web maps it to
 * an inline SVG silhouette here.
 */

// iOS person.fill — head circle + rounded shoulders. Colored via currentColor
// (CSS sets it to white@0.2 to match the iOS foregroundColor).
const PERSON_FILL_SVG =
  '<svg viewBox="0 0 28 28" fill="currentColor" aria-hidden="true">' +
  '<circle cx="14" cy="9" r="5"/>' +
  '<path d="M14 16c-5 0-9 3-9 6.5 0 .85 .65 1.5 1.5 1.5h15c.85 0 1.5-.65 1.5-1.5 0-3.5-4-6.5-9-6.5z"/>' +
  '</svg>';

export default {
  toClient(shared) {
    const { initials, size } = shared ?? {};
    const hasInitials = typeof initials === 'string' && initials.length > 0;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'Avatar',
        componentProps: {
          size: size ?? 'md',
          initials: hasInitials ? initials : '',
          // Only the no-initials variant needs the icon glyph; harmless otherwise.
          icon: hasInitials ? '' : PERSON_FILL_SVG,
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.Avatar',
      state: { component: shared },
    };
  },
};
