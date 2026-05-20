//
//  ReorderHelpers.swift
//  MakeReady
//
//  Shared helpers for Dragula-based drag-to-reorder across the app.
//  Provides DragulaItem conformances and a standard drop indicator.
//

import SwiftUI

// MARK: - DragulaItem Conformances

extension Lesson: DragulaItem {}
extension StudyActivity: DragulaItem {}
extension ScheduledActivity: DragulaItem {}

// MARK: - Standard Drop Indicator

/// Drop indicator shown in place of a dragged card during reorder.
/// Matches the rounded-rectangle placeholder style used across the app.
struct ReorderDropIndicator: View {
    var height: CGFloat = 48
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.06))
            .frame(height: height)
    }
}
