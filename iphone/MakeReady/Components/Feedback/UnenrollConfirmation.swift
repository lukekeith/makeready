//
//  UnenrollConfirmation.swift
//  MakeReady
//
//  Shared unenroll confirmation overlay presentation used by
//  EnrollmentsListPage, MemberHomePage, and StudyProgramHome.
//

import SwiftUI

enum UnenrollConfirmation {

    /// Builds the success message shown after unenrolling, based on the selected option.
    static func successMessage(option: UnenrollOption, programName: String) -> AttributedString {
        switch option {
        case .fullRemoval:
            return AttributedString.safeMarkdown("Your group has been successfully unenrolled from **\(programName)**.")
        case .cancelFuture:
            return AttributedString.safeMarkdown("Future lessons have been cancelled for **\(programName)**. Existing lesson data has been preserved.")
        }
    }

    /// Presents the shared unenroll confirmation overlay.
    /// The caller supplies `onDismiss` since dismiss behavior varies by page.
    static func present(
        overlayManager: OverlayManager,
        option: UnenrollOption,
        programName: String,
        isProcessing: Binding<Bool>,
        onDismiss: @escaping () -> Void
    ) {
        let message = successMessage(option: option, programName: programName)

        overlayManager.present(.confirmationOverlay) {
            ConfirmationOverlay(
                style: .success,
                message: message,
                buttonLabel: "Done",
                isProcessing: isProcessing,
                processingMessage: "Processing unenrollment",
                onDismiss: onDismiss
            )
        }
    }
}
