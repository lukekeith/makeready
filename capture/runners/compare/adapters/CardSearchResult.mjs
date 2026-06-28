/**
 * Adapter: CardSearchResult (component comparison).
 *
 * Projects one canonical search-result description into:
 *   - toClient → card-search-result.vue via the ComponentCapture island
 *   - toIphone → CardSearchResult.swift via the component.CardSearchResult
 *     ViewRegistry case
 *
 * The canonical `shared` block IS the iPhone prop bag, so toIphone passes it
 * straight through (unchanged from the prior generic iphoneCard adapter). For the
 * web twin, the SF Symbol named in `iconSystemName` is mapped to inline filled SVG
 * markup, and the member name is collapsed to avatar initials. `showChevron`
 * defaults to true (only the Lesson variant turns it off).
 */
const WEB_ICONS = {
  // text.book.closed.fill — filled closed book with a page edge carved out.
  'text.book.closed.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"><path d="M6.75 2.5A2.75 2.75 0 0 0 4 5.25v13.5A2.75 2.75 0 0 0 6.75 21.5h11A1.25 1.25 0 0 0 19 20.25V3.75A1.25 1.25 0 0 0 17.75 2.5H6.75ZM6.75 18.25a1 1 0 1 0 0 2H17v-2H6.75Z"/></svg>',
  // list.bullet.rectangle.fill — filled rounded rect with three bullet+line rows knocked out.
  'list.bullet.rectangle.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"><path d="M6.5 3.5A3 3 0 0 0 3.5 6.5v11A3 3 0 0 0 6.5 20.5h11a3 3 0 0 0 3-3V6.5a3 3 0 0 0-3-3H6.5ZM7.75 7.9a1.1 1.1 0 1 0 0 2.2 1.1 1.1 0 0 0 0-2.2ZM11 8.15a.85.85 0 0 0 0 1.7h5.25a.85.85 0 0 0 0-1.7H11ZM7.75 11.9a1.1 1.1 0 1 0 0 2.2 1.1 1.1 0 0 0 0-2.2ZM11 12.15a.85.85 0 0 0 0 1.7h5.25a.85.85 0 0 0 0-1.7H11ZM7.75 15.9a1.1 1.1 0 1 0 0 2.2 1.1 1.1 0 0 0 0-2.2ZM11 16.15a.85.85 0 0 0 0 1.7h5.25a.85.85 0 0 0 0-1.7H11Z"/></svg>',
  // person.3.fill — fallback only (the Group variant renders the loading spinner instead).
  'person.3.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="8" r="3.2"/><circle cx="5.2" cy="9.6" r="2.5"/><circle cx="18.8" cy="9.6" r="2.5"/><path d="M12 12.6c-3.1 0-5.6 1.8-5.6 4.2 0 .9.7 1.4 1.6 1.4h8c.9 0 1.6-.5 1.6-1.4 0-2.4-2.5-4.2-5.6-4.2Z"/><path d="M5 13.1c-2.2 0-3.9 1.3-3.9 2.9 0 .7.5 1.1 1.2 1.1h2.6c-.2-.5-.3-1-.3-1.5 0-.9.3-1.7.9-2.4-.2 0-.3-.1-.5-.1Z"/><path d="M19 13.1c2.2 0 3.9 1.3 3.9 2.9 0 .7-.5 1.1-1.2 1.1h-2.6c.2-.5.3-1 .3-1.5 0-.9-.3-1.7-.9-2.4.2 0 .3-.1.5-.1Z"/></svg>',
};

function initialsFrom(firstName, lastName) {
  return [firstName, lastName]
    .filter(Boolean)
    .map((s) => s.trim().charAt(0))
    .join('')
    .toUpperCase();
}

export default {
  toClient(shared) {
    const {
      title,
      subtitle,
      timeAgo,
      iconSystemName,
      highlightQuery,
      imageUrl,
      firstName,
      lastName,
      isMember,
      showChevron,
    } = shared ?? {};

    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardSearchResult',
        componentProps: {
          title,
          subtitle: subtitle ?? '',
          timeAgo: timeAgo ?? '',
          icon: WEB_ICONS[iconSystemName] ?? '',
          imageUrl: imageUrl ?? '',
          initials: initialsFrom(firstName, lastName),
          isMember: Boolean(isMember),
          showChevron: showChevron !== false,
          highlightQuery: highlightQuery ?? '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardSearchResult',
      state: { component: shared ?? {} },
    };
  },
};
