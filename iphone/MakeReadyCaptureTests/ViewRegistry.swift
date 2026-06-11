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
