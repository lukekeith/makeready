//
//  Route.swift
//  MakeReady
//
//  Phase 3.6 — typed identity for every OverlayManager-presented surface.
//  Replaced the stringly-typed `OverlayID` (deleted in 3.6d; every call site
//  now presents/dismisses by Route). `Route.id` produces the same strings the
//  old `OverlayID` constants did, so the string-keyed OverlayManager methods
//  remain as the underlying implementation — and stay available for the few
//  dynamic per-entity ids (e.g. GlobalSearchPage's lesson/video modals) that
//  have no fixed Route case.
//
//  Presenting a NEW overlay surface: add a Route case + its `id` string, set
//  its `priority`/`chrome`/`dismissOnTapOutside` here (NOT at the call site),
//  then call `overlayManager.present(.yourRoute) { ... }`.
//
//  See docs/audit/iphone-route-enum-2026-06-11-design.md.
//  (3.6c lazy content was REJECTED — see that doc's banner; do not reattempt.)
//

import SwiftUI

enum Route: Equatable, Hashable {

    // MARK: Menus (raw chrome — the menu views handle their own background)
    case userMenu
    case addMenu
    case hamburgerMenu
    case addActivityMenu
    case lessonActionMenu
    case librarySortMenu
    case libraryAddMenu
    case groupsAddMenu
    case groupsInviteMenu
    case bibleVersionMenu
    case exegesisHighlightActionMenu
    case backgroundSourceMenu(blockId: String)

    // MARK: Page / detail modals
    case profilePage
    case createProgram
    case componentsPage
    case globalSearch
    case studyCardsDemoPage
    case studyProgramHome
    case programHome
    case biblePage
    case bibleReader
    case inviteContacts
    case shareInvite
    case notificationFeed
    case exegesisHighlightModal
    case mediaLibraryPicker(blockId: String)
    case stylePicker(blockId: String)

    // MARK: Group / org / member modals
    case createGroup
    case groupHome
    case editGroup
    case orgHome
    case enrollmentFlow
    case programEnrollmentFlow
    case editEnrollmentFlow
    case enrollmentSchedule
    case editEnrollmentDay
    /// Study Sync settings for one enrollment (study-sync notification
    /// actions / deep links). Per-entity so two enrollments never collide.
    case enrollmentSync(enrollmentId: String)
    case memberProfile
    case memberRequestProfile
    case memberRequests
    case memberRequestRespond
    case changeMembership

    // MARK: Feedback / unenroll
    case confirmationOverlay
    case unenrollOptions

    // NOTE: `OverlayID.backgroundPicker(blockId:)` is intentionally omitted — it
    // is no longer an overlay (it's the third slide pane of EditReadActivityPage;
    // see OverlayManager.swift comment near the retired id).

    /// The overlay-stack string id (byte-identical to the old `OverlayID`
    /// values, so pre-3.6d persisted state / dynamic-id interop is unaffected).
    var id: String {
        switch self {
        case .userMenu: return "userMenu"
        case .addMenu: return "addMenu"
        case .hamburgerMenu: return "hamburgerMenu"
        case .addActivityMenu: return "addActivityMenu"
        case .lessonActionMenu: return "lessonActionMenu"
        case .librarySortMenu: return "librarySortMenu"
        case .libraryAddMenu: return "libraryAddMenu"
        case .groupsAddMenu: return "groupsAddMenu"
        case .groupsInviteMenu: return "groupsInviteMenu"
        case .bibleVersionMenu: return "bibleVersionMenu"
        case .exegesisHighlightActionMenu: return "exegesisHighlightActionMenu"
        case .backgroundSourceMenu(let blockId): return "backgroundSourceMenu_\(blockId)"

        case .profilePage: return "profilePage"
        case .createProgram: return "createProgram"
        case .componentsPage: return "componentsPage"
        case .globalSearch: return "globalSearch"
        case .studyCardsDemoPage: return "studyCardsDemoPage"
        case .studyProgramHome: return "studyProgramHome"
        case .programHome: return "programHome"
        case .biblePage: return "biblePage"
        case .bibleReader: return "bibleReader"
        case .inviteContacts: return "inviteContacts"
        case .shareInvite: return "shareInvite"
        case .notificationFeed: return "notificationFeed"
        case .exegesisHighlightModal: return "exegesisHighlightModal"
        case .mediaLibraryPicker(let blockId): return "mediaLibraryPicker_\(blockId)"
        case .stylePicker(let blockId): return "stylePicker_\(blockId)"

        case .createGroup: return "createGroup"
        case .groupHome: return "groupHome"
        case .editGroup: return "editGroup"
        case .orgHome: return "orgHome"
        case .enrollmentFlow: return "enrollmentFlow"
        case .programEnrollmentFlow: return "programEnrollmentFlow"
        case .editEnrollmentFlow: return "editEnrollmentFlow"
        case .enrollmentSchedule: return "enrollmentSchedule"
        case .editEnrollmentDay: return "editEnrollmentDay"
        case .enrollmentSync(let enrollmentId): return "enrollmentSync_\(enrollmentId)"
        case .memberProfile: return "memberProfile"
        case .memberRequestProfile: return "memberRequestProfile"
        case .memberRequests: return "memberRequests"
        case .memberRequestRespond: return "memberRequestRespond"
        case .changeMembership: return "changeMembership"

        case .confirmationOverlay: return "confirmationOverlay"
        case .unenrollOptions: return "unenrollOptions"
        }
    }

    /// The z-index bucket this surface presents in — folds the priority that
    /// was previously passed positionally at each call site into the type.
    /// Verified against every live call site during 3.6d:
    /// `unenrollOptions` is presented via `presentModal` with default `.modal`
    /// priority (NOT `.menu` as the design draft guessed); `stylePicker` is
    /// presented via `presentMenu` with default `.menu` priority.
    var priority: OverlayPriority {
        switch self {
        case .addActivityMenu, .confirmationOverlay, .memberRequestRespond, .changeMembership:
            return .topLevel
        case .userMenu, .addMenu, .hamburgerMenu, .lessonActionMenu,
             .librarySortMenu, .libraryAddMenu, .groupsAddMenu, .groupsInviteMenu,
             .bibleVersionMenu, .exegesisHighlightActionMenu, .backgroundSourceMenu,
             .stylePicker:
            return .menu
        default:
            return .modal
        }
    }

    /// Which chrome wrapper this route uses, so `present(_:content:)` picks
    /// presentModal vs presentMenu vs presentPage vs raw rather than the call
    /// site choosing. Refined during 3.6d to match every live call site
    /// byte-for-byte (prime directive: zero behavior change):
    /// - `addActivityMenu` and `confirmationOverlay` are presented RAW —
    ///   `AddActivityMenu`/`ConfirmationOverlay` own their chrome.
    /// - `memberRequests` is push-style (`presentPage`).
    enum Chrome { case modal, menu, page, raw }
    var chrome: Chrome {
        switch self {
        case .addActivityMenu, .confirmationOverlay, .memberRequestRespond, .changeMembership:
            return .raw
        case .memberRequests:
            return .page
        default:
            return priority == .menu ? .menu : .modal
        }
    }

    /// Whether tapping the dark background dismisses (modal chrome only) —
    /// folds the per-call-site `dismissOnTapOutside:` flag into the type.
    /// These flows have explicit Cancel/Done affordances and multi-step state
    /// that a stray background tap must not discard. Every live call site for
    /// these four routes passed `dismissOnTapOutside: false`; all other modal
    /// routes used the default `true`.
    var dismissOnTapOutside: Bool {
        switch self {
        case .enrollmentSchedule, .editEnrollmentDay,
             .enrollmentFlow, .programEnrollmentFlow, .editEnrollmentFlow:
            return false
        default:
            return true
        }
    }
}

// MARK: - Route-keyed OverlayManager API (3.6b, additive)

extension OverlayManager {

    /// Present `route` using the chrome its type declares. Delegates to the
    /// existing string-keyed methods via `route.id`, so this coexists with the
    /// legacy `presentModal(id:)`/`presentMenu(id:)` call sites during migration.
    func present<V: View>(_ route: Route, @ViewBuilder content: () -> V) {
        switch route.chrome {
        case .modal:
            presentModal(
                id: route.id,
                priority: route.priority,
                dismissOnTapOutside: route.dismissOnTapOutside,
                content: content
            )
        case .menu:
            presentMenu(id: route.id, priority: route.priority, content: content)
        case .page:
            presentPage(id: route.id, priority: route.priority, content: content)
        case .raw:
            present(id: route.id, priority: route.priority, content: content)
        }
    }

    func dismiss(_ route: Route) {
        dismiss(id: route.id)
    }

    func dismiss(_ route: Route, then completion: @escaping () -> Void) {
        dismiss(id: route.id, then: completion)
    }

    func isPresented(_ route: Route) -> Bool {
        isPresented(id: route.id)
    }
}
