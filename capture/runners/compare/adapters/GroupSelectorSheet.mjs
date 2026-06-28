/**
 * Adapter: GroupSelectorSheet (component comparison).
 *
 * Projects the canonical sheet description into:
 *   - toClient → group-selector-sheet.vue via the ComponentCapture island
 *   - toIphone → component.GroupSelectorSheet ViewRegistry case
 *               (Components/Display/GroupSelectorSheet.swift)
 *
 * ⚠️ The iPhone GroupSelectorSheet is SELF-CONTAINED: it drives its list from an
 * internal `GroupFixtureManager` @StateObject (hardcoded — Youth Group 12 /
 * Sunday Service 45 / Bible Study 8 / Worship Team 15) and the ViewRegistry
 * instantiates it as `GroupSelectorSheet(selectedGroup: .constant(nil))`. So the
 * iPhone reference IGNORES the fixture's `groupList` / `selectedGroupName` —
 * BOTH variants (Default + NoneSelected) render the same hardcoded list with no
 * selection. The trailing close button (a NavigationStack ToolbarItem) also does
 * not render in the SwiftUI ImageRenderer snapshot, only the inline title does.
 *
 * To match that reference exactly the client side renders the SAME hardcoded
 * list, omits the selection, and omits the close icon — the same "project what
 * the iPhone actually renders" approach the Avatar / FullScreenImageViewer
 * adapters use for their snapshot fallbacks. The Vue twin itself stays fully
 * data-driven (it can render any groupList, a selected row, and the close
 * button); only this snapshot projection is pinned to the hardcoded fixture.
 */

// The iPhone GroupFixtureManager's hardcoded list (ContactsManager.swift) — what
// the snapshot actually shows, regardless of the fixture `shared`.
const IPHONE_FIXTURE_GROUPS = [
  { name: 'Youth Group', memberCount: 12 },
  { name: 'Sunday Service', memberCount: 45 },
  { name: 'Bible Study', memberCount: 8 },
  { name: 'Worship Team', memberCount: 15 },
];

export default {
  toClient(_shared) {
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone snapshot canvas.
      clip: '.capture-wrap',
      data: {
        component: 'GroupSelectorSheet',
        componentProps: {
          // Mirror the iPhone's hardcoded GroupFixtureManager list + nil
          // selection so the web pane matches the reference exactly.
          groupList: IPHONE_FIXTURE_GROUPS,
          selectedGroupName: '',
          title: 'Select Group',
          // No close icon → matches the snapshot (ToolbarItem doesn't render).
          closeIcon: '',
        },
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.GroupSelectorSheet',
      state: { component: shared },
    };
  },
};
