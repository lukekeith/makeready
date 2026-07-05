// Overlay route registry — web twin of iPhone Services/Route.swift.
//
// Every overlay surface is registered here as a typed route that folds four
// decisions into the definition: a stable id, a priority (z-bucket), a chrome
// kind, and tap-outside dismissal. Call sites never choose these — they call
// overlay.present(ROUTES.someRoute, Component, props) and the route decides.
// Mirrors the iOS derivation rules: priority defaults to `modal`; chrome
// defaults from priority (menu → menu chrome, else modal); dismissOnTapOutside
// defaults to true.

export const OverlayPriority = {
  /** Standard modals (forms, detail pages). */
  modal: 100,
  /** Bottom menus (action / add / user menus). */
  menu: 200,
  /** Always-on-top (confirmations, alerts, sub-menus inside modals). */
  topLevel: 300,
} as const

export type OverlayChrome = 'modal' | 'menu' | 'raw'

export interface OverlayRoute {
  id: string
  priority: number
  chrome: OverlayChrome
  dismissOnTapOutside: boolean
}

function route(
  id: string,
  overrides: Partial<Omit<OverlayRoute, 'id'>> = {},
): OverlayRoute {
  const priority = overrides.priority ?? OverlayPriority.modal
  return {
    id,
    priority,
    chrome:
      overrides.chrome ?? (priority === OverlayPriority.menu ? 'menu' : 'modal'),
    dismissOnTapOutside: overrides.dismissOnTapOutside ?? true,
  }
}

// Registered routes (grow this as screens are ported — same names as iOS).
export const ROUTES = {
  programHome: route('programHome'),
  // iOS Route.createProgram — default modal chrome, tap-outside dismisses.
  createProgram: route('createProgram'),
  // iOS Route.libraryAddMenu — .menu priority, menu chrome (ManagedMenuView).
  libraryAddMenu: route('libraryAddMenu', { priority: OverlayPriority.menu }),
  // iOS Route.librarySortMenu (registered-but-unused on iOS: the native Menu
  // popover has no web idiom, so web presents the sort options through this).
  librarySortMenu: route('librarySortMenu', { priority: OverlayPriority.menu }),
  addActivityMenu: route('addActivityMenu', {
    priority: OverlayPriority.topLevel,
    chrome: 'raw',
  }),
  confirmationOverlay: route('confirmationOverlay', {
    priority: OverlayPriority.topLevel,
    chrome: 'raw',
  }),
  // iOS Route.groupHome — default modal priority/chrome, tap-outside dismisses.
  groupHome: route('groupHome'),
  // iOS Route.lessonActionMenu — .menu priority, menu chrome (ManagedMenuView).
  lessonActionMenu: route('lessonActionMenu', { priority: OverlayPriority.menu }),
} as const
