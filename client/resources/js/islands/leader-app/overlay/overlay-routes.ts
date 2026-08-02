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

export type OverlayChrome = 'modal' | 'menu' | 'raw' | 'page'

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
  // iOS Route.memberProfile — default modal priority/chrome, tap-outside dismisses.
  memberProfile: route('memberProfile'),
  // iOS Route.memberRequests — the ONLY `.page` chrome route (ManagedPageView
  // horizontal push). iOS dismissOnTapOutside is `true` but DEAD metadata:
  // page chrome never reads it (the scrim has hit-testing off).
  memberRequests: route('memberRequests', { chrome: 'page' }),
  // iOS Route.lessonActionMenu — .menu priority, menu chrome (ManagedMenuView).
  lessonActionMenu: route('lessonActionMenu', { priority: OverlayPriority.menu }),
  // Notifications feed (study-sync phase 6) — default modal chrome; opened
  // from the dashboard banner. Web-first: no iOS Route twin yet.
  notifications: route('notifications'),
  // iOS Route.memberRequestRespond — topLevel RAW (the modal ships its own
  // opaque appBackground wash; tap-outside is swallowed on iOS, so the flag
  // here is dead metadata just like on iOS).
  memberRequestRespond: route('memberRequestRespond', {
    priority: OverlayPriority.topLevel,
    chrome: 'raw',
  }),
  // iOS Route.changeMembership — topLevel RAW (same contract).
  changeMembership: route('changeMembership', {
    priority: OverlayPriority.topLevel,
    chrome: 'raw',
  }),
  // iOS Route.enrollmentFlow / .programEnrollmentFlow — the 3-panel enrollment
  // wizard (group entry / program entry). Modal chrome, tap-outside NEVER
  // dismisses (Route.swift:186-188).
  enrollmentFlow: route('enrollmentFlow', { dismissOnTapOutside: false }),
  programEnrollmentFlow: route('programEnrollmentFlow', {
    dismissOnTapOutside: false,
  }),
  // iOS Route.enrollmentSchedule — modal, tap-outside NEVER dismisses.
  enrollmentSchedule: route('enrollmentSchedule', { dismissOnTapOutside: false }),
  // iOS Route.enrollmentActionMenu — .menu priority, menu chrome.
  enrollmentActionMenu: route('enrollmentActionMenu', {
    priority: OverlayPriority.menu,
  }),
  // iOS Route.unenrollOptions — modal, tap-outside DOES dismiss (default).
  unenrollOptions: route('unenrollOptions'),
} as const
