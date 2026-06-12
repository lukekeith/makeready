//
//  LessonActivity.swift
//  MakeReady
//
//  Activity row component for lesson cards
//

import SwiftUI

public enum LessonActivityStyle {
    case `default`  // Icon + type label + title
    case single     // Icon only + title (no type label)
    case select     // Icon + type label + purple label text
}

struct LessonActivity: View {
    let data: LessonActivityData
    let style: LessonActivityStyle

    var body: some View {
        HStack(spacing: 8) {
            // Left section: Icon
            Image(systemName: data.icon)
                .font(Typography.s14)
                .foregroundColor(.white)
                .frame(width: 14, height: 14)

            // Middle section: Optional type label
            if style != .single, let type = data.type {
                Text(type)
                    .font(Typography.s12Bold)
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(0.1)
            }

            // Right section: Title
            if style == .select {
                Text(data.label ?? data.title)
                    .font(Typography.s12)
                    .foregroundColor(Color.brandPrimary)
                    .tracking(0.1)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text(data.title)
                    .font(Typography.s12Bold)
                    .foregroundColor(.white)
                    .tracking(0.1)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // Default style
            LessonActivity(
                data: LessonActivityData(
                    icon: "book",
                    type: "SOAP",
                    title: "Romans 1:1-2"
                ),
                style: .default
            )
            .padding(.horizontal, 20)

            // Single style
            LessonActivity(
                data: LessonActivityData(
                    icon: "hand.thumbsup.fill",
                    type: nil,
                    title: "Romans 1:1-2"
                ),
                style: .single
            )
            .padding(.horizontal, 20)

            // Select style
            LessonActivity(
                data: LessonActivityData(
                    icon: "book",
                    type: "SOAP",
                    title: "Romans 1:1-2",
                    label: "Label"
                ),
                style: .select
            )
            .padding(.horizontal, 20)
        }
    }
}
