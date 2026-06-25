//
//  ViewRegistry.swift
//  MakeReadyCaptureTests
//
//  Maps fixture "view" keys to SwiftUI views.
//  Add new cases here as you add capture fixtures for more screens.
//

import SwiftUI
@testable import MakeReady

enum ViewRegistryError: Error {
    case unknownView(String)
}

/// Builds the SwiftUI view for a given fixture, wrapping it with
/// the required environment objects (AuthManager, OverlayManager).
@MainActor
func buildCaptureView(for fixture: CaptureFixture) throws -> AnyView {
    let authManager = makeMockAuthManager(from: fixture.auth)

    switch fixture.view {
    case "component.card-study":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.card-study: missing state.component")
        }
        let status: CardStatus = {
            switch c.status {
            case "pending": return .pending
            case "new": return .new
            default: return .confirmed
            }
        }()
        let imageStyle: CardImageStyle = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(imageURL: cover)
            }
            return .icon(systemName: c.iconSystemName ?? "book.fill", backgroundColor: nil, foregroundColor: nil)
        }()
        let metadata = (c.metadata ?? []).map { DataItem(icon: $0.icon ?? "circle", value: $0.value) }
        let data = CardStudyData(
            id: "capture-card-study",
            title: c.title ?? "",
            description: c.description,
            type: c.type,
            imageStyle: imageStyle,
            metadata: metadata,
            status: status,
            onTap: nil
        )
        return AnyView(CardStudy(data: data).padding(16))

    case "component.GroupCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.GroupCard: missing state.component")
        }
        let imageStyle: CardImageStyle = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(imageURL: cover)
            }
            return .icon(systemName: "person.2.fill", backgroundColor: nil, foregroundColor: nil)
        }()
        let metadata = (c.metadata ?? []).map { DataItem(icon: $0.icon ?? "person.2.fill", value: $0.value) }
        let data = CardGroupData(
            id: "capture-group-card",
            title: c.title ?? "",
            imageStyle: imageStyle,
            metadata: metadata,
            isSelected: c.selected ?? false
        )
        if (c.size ?? "Row") == "Mini" {
            return AnyView(CardGroupMini(data: data).padding(16))
        }
        return AnyView(CardGroup(data: data).padding(16))

    case "pages.login":
        return AnyView(
            LoginView()
                .environment(authManager)
        )

    case "pages.home":
        return AnyView(
            MainView()
                .environment(authManager)
        )

    case "pages.group-home":
        // Group is seeded into AppState by setupCaptureState; GroupHomePage.init
        // reads AppState.groups[groupId] for an immediate (non-loading) first paint.
        let groupId = fixture.state?.groupId
            ?? fixture.state?.groups?.first?.id
            ?? "group-1"
        return AnyView(
            GroupHomePage(
                overlayManager: OverlayManager(),
                groupId: groupId,
                onDismiss: {}
            )
            .environment(authManager)
        )

    case "pages.create-program":
        return AnyView(
            CreateProgramPage(overlayManager: OverlayManager())
                .environment(authManager)
        )

    case "pages.edit-read-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let lessonId = fixture.state?.lessonId ?? "capture-lesson-0"
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-read-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditReadActivityPage(
                activity: activity,
                lessonId: lessonId,
                programId: programId,
                onCancel: {},
                onSave: { _ in }
            )
            .environment(OverlayManager())
            .environment(authManager)
        )

    case "pages.edit-exegesis-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-exegesis-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditExegesisActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: {}
            )
            .environment(OverlayManager())
            .environment(authManager)
        )

    case "pages.program-home":
        let programId = fixture.state?.programId ?? "capture-prog-0"
        var coverImage: UIImage? = nil
        if let imagePath = fixture.state?.programCoverImagePath {
            let fullPath = (CaptureFixtureLoader.captureRootPath() as NSString).appendingPathComponent(imagePath)
            coverImage = UIImage(contentsOfFile: fullPath)
        }
        return AnyView(
            ProgramHomePage(
                overlayManager: OverlayManager(),
                programId: programId,
                onShowAddActivityMenu: nil,
                initialCoverImage: coverImage
            )
            .environment(authManager)
        )

    case "pages.video-activity-picker":
        return AnyView(
            VideoActivityPicker(
                onDismiss: {},
                onVideoSelected: { _ in }
            )
            .environment(authManager)
        )

    case "pages.edit-youtube-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-youtube-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditYouTubeActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: { _, _, _, _ in }
            )
            .environment(authManager)
        )

    case "pages.edit-user-input-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-user-input-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditUserInputActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: { _, _, _, _, _ in }
            )
            .environment(authManager)
        )

    default:
        throw ViewRegistryError.unknownView(fixture.view)
    }
}
