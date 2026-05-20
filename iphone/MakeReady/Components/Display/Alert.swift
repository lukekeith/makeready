//
//  Alert.swift
//  MakeReady
//
//  Alert component with warning and critical variants
//

import SwiftUI

enum AlertVariant {
    case warning
    case critical
}

struct Alert: View {
    let message: String
    let variant: AlertVariant

    private var backgroundColor: Color {
        switch variant {
        case .warning:
            return Color(hex: "#F4FF76").opacity(0.2)
        case .critical:
            return Color(hex: "#FF4759").opacity(0.2)
        }
    }

    private var iconColor: Color {
        switch variant {
        case .warning:
            return Color(hex: "#F4FF76")
        case .critical:
            return Color(hex: "#FF4759")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

// MARK: - Previews

#Preview("Warning Alert") {
    ZStack {
        Color(hex: "#0a0a0f")
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Alert(
                message: "Enrollment cannot take place on a day that already has a study activity assigned. All scheduled items must be removed before you can enroll on this date.",
                variant: .warning
            )
            .padding(.horizontal, 16)
        }
    }
}

#Preview("Critical Alert") {
    ZStack {
        Color(hex: "#0a0a0f")
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Alert(
                message: "Enrollment cannot take place on a day that already has a study activity assigned. All scheduled items must be removed before you can enroll on this date.",
                variant: .critical
            )
            .padding(.horizontal, 16)
        }
    }
}

#Preview("Both Variants") {
    ZStack {
        Color(hex: "#0a0a0f")
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Alert(
                message: "This is a warning message to inform you about a potential issue that needs attention.",
                variant: .warning
            )

            Alert(
                message: "This is a critical error that requires immediate action. Please address this issue before proceeding.",
                variant: .critical
            )
        }
        .padding(.horizontal, 16)
    }
}
