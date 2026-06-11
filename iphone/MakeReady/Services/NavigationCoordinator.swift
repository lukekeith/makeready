//
//  NavigationCoordinator.swift
//  MakeReady
//
//  Phase 3.8 — typed cross-page navigation. Owns the tab/sub-tab state that
//  MainView previously held in loose @State vars, and is the single entry
//  point for deep links, push-notification routing, and cross-tab jumps
//  (KPI taps, notification feed taps).
//
//  Pages migrate their presentation booleans to coordinator destinations
//  OPPORTUNISTICALLY — when you're already touching a page's navigation,
//  not as a bulk sweep. New deep links / notification destinations /
//  cross-tab jumps go through `navigate(to:)` — see the /nav-route skill.
//
//  Overlay presentation itself stays on OverlayManager + Route
//  (see MODAL_GUIDE.md); the coordinator decides WHERE to go, Route decides
//  HOW a surface presents.
//

import SwiftUI

/// Typed destinations for cross-tab navigation, deep links, and
/// push-notification routing.
enum NavDestination: Equatable {
    case tab(MainTab)
    /// Groups tab opened on a specific sub-tab (0 = Groups, 1 = Members,
    /// 2 = Enrolled).
    case groupsTab(subTab: Int)
    /// Study-programs tab opened on a specific sub-tab.
    case studyProgramsTab(subTab: Int)
    /// Group home presented as a modal over the groups tab.
    case groupHome(groupId: String)
    /// Members tab — pending join-request cards surface at the top.
    case joinRequests
    /// Library tab; the `.makeready` file-import flow consumes the pending
    /// deep link itself (MainLibrary observes and clears it).
    case libraryImport
}

@Observable
@MainActor
final class NavigationCoordinator {

    /// The active root tab (was MainView's `currentTab`).
    var tab: MainTab = .home

    /// One-shot sub-tab signals, consumed (nilled) by MainGroups /
    /// MainPrograms after they switch.
    var groupsSubTab: Int? = nil
    var studyProgramsSubTab: Int? = nil

    /// Wired by MainView before the first deep link can arrive. The
    /// coordinator presents destination overlays (e.g. group home) through
    /// it; weak because MainView owns both objects' lifetimes.
    weak var overlayManager: OverlayManager?

    func navigate(to destination: NavDestination) {
        switch destination {
        case .tab(let newTab):
            tab = newTab

        case .groupsTab(let subTab):
            groupsSubTab = subTab
            tab = .groups

        case .studyProgramsTab(let subTab):
            studyProgramsSubTab = subTab
            tab = .studyPrograms

        case .joinRequests:
            // Members sub-tab; request cards render at the top of it.
            navigate(to: .groupsTab(subTab: 1))

        case .groupHome(let groupId):
            tab = .groups
            presentGroupHome(groupId: groupId)

        case .libraryImport:
            tab = .library
        }
    }

    /// Deep-link / push-notification entry point. This switch is EXHAUSTIVE
    /// over `DeepLink` ON PURPOSE (no `default:`) — adding a DeepLink case
    /// must force a routing decision here. See the /nav-route skill.
    func handle(deepLink: DeepLink) {
        switch deepLink {
        case .joinRequests:
            NSLog("🔗 NavigationCoordinator: join requests deep link")
            navigate(to: .joinRequests)
            PushNotificationManager.shared.clearPendingDeepLink()

        case .group(let groupId):
            NSLog("🔗 NavigationCoordinator: group deep link for %@", groupId)
            navigate(to: .groupHome(groupId: groupId))
            PushNotificationManager.shared.clearPendingDeepLink()

        case .importFile:
            NSLog("🔗 NavigationCoordinator: .makeready import deep link")
            // MainLibrary observes pendingDeepLink and runs the import
            // preview flow itself. Do NOT clear the deep link here —
            // MainLibrary clears it after consuming the URL.
            navigate(to: .libraryImport)

        case .none:
            break
        }
    }

    /// Present the group home page as a modal overlay (the `.groupHome`
    /// deep-link destination).
    private func presentGroupHome(groupId: String) {
        guard let overlayManager else {
            NSLog("⚠️ NavigationCoordinator: overlayManager not wired; dropping groupHome navigation")
            return
        }
        overlayManager.present(.groupHome) {
            GroupHomePage(
                overlayManager: overlayManager,
                groupId: groupId,
                onDismiss: { [weak overlayManager] in
                    overlayManager?.dismiss(.groupHome)
                }
            )
        }
    }
}
