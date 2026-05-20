//
//  LessonDetailPage.swift
//  MakeReady
//
//  Wrapper that loads lesson data from AppState and presents EditDay.
//  Used when tapping a lesson from global search results.
//

import SwiftUI

struct SearchLessonDetail: View {
    let lessonId: String
    let programId: String?
    let onDismiss: () -> Void

    private var state: AppState { AppState.shared }

    private var lesson: Lesson? {
        guard let l = state.lessons[lessonId] else { return nil }
        var copy = l
        let activityIds = state.lessonActivityIndex.get(lessonId)
        copy.activities = state.activities.getMany(activityIds).sorted { $0.orderNumber < $1.orderNumber }
        return copy
    }

    @State private var isLoading = false
    @State private var isPresented = true

    var body: some View {
        if let lesson = lesson {
            EditDay(
                isPresented: Binding(
                    get: { isPresented },
                    set: { newValue in
                        isPresented = newValue
                        if !newValue { onDismiss() }
                    }
                ),
                programId: programId ?? lesson.studyProgramId ?? "",
                lesson: lesson,
                onLessonUpdated: { _ in },
                onShowAddActivityMenu: nil
            )
        } else if isLoading {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ProgressView()
                    .tint(.white30)
            }
        } else {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.white20)
                    Text("Lesson not found")
                        .font(.system(size: 15))
                        .foregroundColor(.white50)
                }
            }
            .onAppear {
                if let pid = programId {
                    isLoading = true
                    Task {
                        _ = try? await ProgramActions().getProgram(id: pid)
                        isLoading = false
                    }
                }
            }
        }
    }
}
