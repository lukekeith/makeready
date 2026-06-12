//
//  EnrollmentCard.swift
//  MakeReady
//
//  Card component for displaying enrollment with study program info.
//  Shows status indicator: clock + date range for active, checkmark + "Completed" for completed.
//

import SwiftUI

struct EnrollmentCard: View {
    let enrollment: EnrollmentWithProgram
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Program cover image
                programImage

                // Program info + status
                VStack(alignment: .leading, spacing: 4) {
                    // Program name
                    Text(enrollment.studyProgram?.name ?? "Study Program")
                        .font(Typography.s15Semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Days count
                    Text("\(enrollment.studyProgram?.days ?? 0) days")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.5))

                    // Status indicator
                    statusIndicator
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(Typography.s14)
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Program Image

    private var programImage: some View {
        Group {
            if let imageUrl = enrollment.studyProgram?.coverImageUrl {
                CachedCardImage(
                    url: imageUrl.mediumImageUrl,
                    fallbackUrl: imageUrl,
                    width: 64,
                    height: 64,
                    fallback: { imagePlaceholder }
                )
            } else {
                imagePlaceholder
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.brandPrimary.opacity(0.3))
            .overlay(
                Image(systemName: "book.fill")
                    .font(Typography.s20)
                    .foregroundColor(.white.opacity(0.5))
            )
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            if enrollment.isCompleted {
                // Completed: green checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(Typography.s12)
                    .foregroundColor(Color(hex: "#2ed573"))

                Text("Completed")
                    .font(Typography.s12Medium)
                    .foregroundColor(Color(hex: "#2ed573"))
            } else {
                // Active: clock + date range
                Image(systemName: "clock")
                    .font(Typography.s12)
                    .foregroundColor(Color.brandPrimary)

                Text(enrollment.dateRangeString)
                    .font(Typography.s12Medium)
                    .foregroundColor(Color.brandPrimary)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            // Active enrollment
            EnrollmentCard(enrollment: EnrollmentWithProgram(
                id: "1",
                groupId: "g1",
                studyProgramId: "p1",
                startDate: Date(),
                endDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
                enabledDays: "[\"Mon\",\"Tue\",\"Wed\",\"Thu\",\"Fri\"]",
                smsTime: "09:00",
                timezone: "America/Chicago",
                requireResponse: false,
                createdAt: Date(),
                updatedAt: Date(),
                studyProgram: StudyProgramSummary(
                    id: "p1",
                    name: "Foundation",
                    description: "30-day foundation study",
                    days: 30,
                    coverImageUrl: "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=200"
                )
            ))

            // Completed enrollment
            EnrollmentCard(enrollment: EnrollmentWithProgram(
                id: "2",
                groupId: "g1",
                studyProgramId: "p2",
                startDate: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                endDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                enabledDays: "[\"Mon\",\"Wed\",\"Fri\"]",
                smsTime: "08:00",
                timezone: "America/Chicago",
                requireResponse: false,
                createdAt: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                updatedAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                studyProgram: StudyProgramSummary(
                    id: "p2",
                    name: "Advanced Leadership",
                    description: "21-day leadership study",
                    days: 21,
                    coverImageUrl: nil
                )
            ))
        }
        .padding(16)
    }
}
