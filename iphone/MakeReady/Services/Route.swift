//
//  Route.swift
//  MakeReady
//
//  Phase 3.6 — typed identity for every OverlayManager-presented surface.
//  Replaces the stringly-typed `OverlayID`. `Route.id` returns the SAME string
//  the legacy `OverlayID` values produce, so a route-keyed `present(_:)` and a
//  legacy string `dismiss(id:)` interoperate during the migration — call sites
//  move one group at a time, no flag day.
//
//  This file is additive (3.6a + 3.6b): nothing here changes behavior. The
//  legacy `OverlayID` enum and the string-keyed OverlayManager methods keep
//  working until 3.6d migrates the last call site. The lazy-content change
//  (3.6c) lives separately and is gated on a capture diff.
//
//  See docs/audit/iphone-route-enum-2026-06-11-design.md.
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
    case enrollmentSchedule
    case editEnrollmentDay
    case memberProfile
    case memberRequestProfile
    case memberRequests

    // MARK: Feedback / unenroll
    case confirmationOverlay
    case unenrollOptions

    // NOTE: `OverlayID.backgroundPicker(blockId:)` is intentionally omitted — it
    // is no longer an overlay (it's the third slide pane of EditReadActivityPage;
    // see OverlayManager.swift comment near the retired id).

    /// Bridges to the legacy string id. Must stay byte-identical to the old
    /// `OverlayID` values until 3.6d removes the last string call site.
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
        case .enrollmentSchedule: return "enrollmentSchedule"
        case .editEnrollmentDay: return "editEnrollmentDay"
        case .memberProfile: return "memberProfile"
        case .memberRequestProfile: return "memberRequestProfile"
        case .memberRequests: return "memberRequests"

        case .confirmationOverlay: return "confirmationOverlay"
        case .unenrollOptions: return "unenrollOptions"
        }
    }

    /// The z-index bucket this surface presents in — folds the priority that
    /// was previously passed positionally at each call site into the type.
    var priority: OverlayPriority {
        switch self {
        case .addActivityMenu, .confirmationOverlay:
            return .topLevel
        case .userMenu, .addMenu, .hamburgerMenu, .lessonActionMenu,
             .librarySortMenu, .libraryAddMenu, .groupsAddMenu, .groupsInviteMenu,
             .bibleVersionMenu, .exegesisHighlightActionMenu, .backgroundSourceMenu,
             .unenrollOptions:
            return .menu
        default:
            return .modal
        }
    }

    /// Which chrome wrapper this route uses, so a future `present(_:content:)`
    /// can pick presentModal vs presentMenu rather than the call site choosing.
    /// 3.6d refines per-route (e.g. routes that should use presentPage) as the
    /// matching call sites migrate; the menu/modal split below is the safe
    /// default and matches today's priority buckets.
    enum Chrome { case modal, menu, page, raw }
    var chrome: Chrome {
        priority == .menu ? .menu : .modal
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
            presentModal(id: route.id, priority: route.priority, content: content)
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
