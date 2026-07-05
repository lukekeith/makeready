/**
 * Adapter: AddActivityMenu (component comparison, group Navigation).
 *
 * The iPhone "Select activity" full-screen overlay
 * (Components/Navigation/AddActivityMenu.swift) vs the production web island
 * component (islands/leader-app/components/add-activity-menu.vue) — the island
 * component IS the twin (registered directly in ComponentCapture).
 *
 * Both sides hardcode the 5 activity types (READ/WRITE/VIDEO/YOUTUBE/EXEGESIS)
 * exactly like their sources — the fixture's `shared.activityTypes` block is
 * documentation, not data (neither side binds it).
 *
 * Web: renders full-bleed via pages.leader-twin (the sheet is
 * position:absolute inset:0) with the capture-only statusBar prop; holdMs
 * lets the 200ms fade + staggered tile entrance (~450ms total) settle.
 *
 * iPhone: pages.add-activity-menu ViewRegistry case (device layout — the view
 * fills the screen, so the old component.* sizeThatFits capture was
 * unsuitable). The case wraps the view in a transaction that disables
 * animations so the onAppear fade-from-opacity-0 resolves instantly.
 */
export default {
  toClient() {
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      holdMs: 800,
      data: {
        component: 'AddActivityMenu',
        componentProps: { statusBar: true },
      },
    };
  },

  toIphone() {
    return {
      platform: 'iphone',
      view: 'pages.add-activity-menu',
      state: {},
    };
  },
};
