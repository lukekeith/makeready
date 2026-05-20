//
//  CardStudySelectable.swift
//  MakeReady
//
//  Selectable study program card for enrollment flow
//

import SwiftUI

struct CardStudySelectableData: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let lessonCount: Int
    let imageURL: String?
    let isSelected: Bool
    let isPublished: Bool
    let enrolledUntilDate: Date?  // End date of active enrollment (nil if not enrolled)
    let isDisabled: Bool          // Disable selection for enrolled programs
    let onTap: (() -> Void)?

    init(
        id: String,
        title: String,
        description: String? = nil,
        lessonCount: Int,
        imageURL: String? = nil,
        isSelected: Bool = false,
        isPublished: Bool = true,
        enrolledUntilDate: Date? = nil,
        isDisabled: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.lessonCount = lessonCount
        self.imageURL = imageURL
        self.isSelected = isSelected
        self.isPublished = isPublished
        self.enrolledUntilDate = enrolledUntilDate
        self.isDisabled = isDisabled
        self.onTap = onTap
    }

    /// Formatted "enrolled until Jun 30" text
    var enrolledUntilText: String? {
        guard let date = enrolledUntilDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "enrolled until \(formatter.string(from: date))"
    }

    static func == (lhs: CardStudySelectableData, rhs: CardStudySelectableData) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.description == rhs.description &&
               lhs.lessonCount == rhs.lessonCount &&
               lhs.imageURL == rhs.imageURL &&
               lhs.isSelected == rhs.isSelected &&
               lhs.isPublished == rhs.isPublished &&
               lhs.enrolledUntilDate == rhs.enrolledUntilDate &&
               lhs.isDisabled == rhs.isDisabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(description)
        hasher.combine(lessonCount)
        hasher.combine(imageURL)
        hasher.combine(isSelected)
        hasher.combine(isPublished)
        hasher.combine(enrolledUntilDate)
        hasher.combine(isDisabled)
    }
}

struct CardStudySelectable: View {
    let data: CardStudySelectableData

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            HStack(spacing: 16) {
                // Left: Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let description = data.description {
                        Text(description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    // Lesson count, published status, and enrollment status
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.5))
                                Text("\(data.lessonCount) days")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.5))
                            }

                            // Published/Draft badge
                            Text(data.isPublished ? "Published" : "Draft")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(data.isPublished ? Color(hex: "#234D2E") : Color(hex: "#D3D4D7"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(data.isPublished ? Color(hex: "#57DB5D") : Color(hex: "#6E7079"))
                                .cornerRadius(4)
                        }

                        // Enrolled until text (if currently enrolled)
                        if let enrolledText = data.enrolledUntilText {
                            Text(enrolledText)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color.brandPrimary)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer(minLength: 0)

                // Right: Image with selection overlay (72×108 portrait)
                imageView
                    .frame(width: 72, height: 108)
            }
            .padding(16)
            .frame(height: 140)
            .background(data.isSelected && !data.isDisabled ? Color.backgroundPurple : Color.cardBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(data.isSelected && !data.isDisabled ? Color.brandPrimary : Color.clear, lineWidth: 2)
            )
            .opacity(data.isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(data.isDisabled)
        // NOTE: Do NOT add implicit .animation() here - it breaks page transitions
        // Selection animation is handled by withAnimation() in the parent view
    }

    // MARK: - Image View

    @ViewBuilder
    private var imageView: some View {
        ZStack {
            // Background image
            if let imageURL = data.imageURL {
                CachedCardImage(
                    url: imageURL.mediumImageUrl,
                    fallbackUrl: imageURL,
                    width: 72,
                    height: 108,
                    fallback: { iconFallback }
                )
            } else {
                iconFallback
            }

            // Selection overlay (only show if not disabled)
            if data.isSelected && !data.isDisabled {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.brandPrimary.opacity(0.8))
                    .frame(width: 72, height: 108)
                    .overlay(
                        Image("IconCheckmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    )
            }
        }
    }

    private var iconFallback: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.iconContainerBackground)
            .frame(width: 72, height: 108)
            .overlay(
                Image(systemName: "book.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            Text("Selectable Study Cards")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            CardStudySelectable(
                data: CardStudySelectableData(
                    id: "1",
                    title: "Romans Deep Dive",
                    description: "A 30-day journey through the book of Romans",
                    lessonCount: 30,
                    imageURL: "https://images.unsplash.com/photo-1506869640319-fe1a24fd76dc?w=144&h=216&fit=crop",
                    isSelected: false
                )
            )

            CardStudySelectable(
                data: CardStudySelectableData(
                    id: "2",
                    title: "Gospel of John",
                    description: "Explore the life of Jesus through John's eyes",
                    lessonCount: 21,
                    imageURL: nil,
                    isSelected: true
                )
            )

            CardStudySelectable(
                data: CardStudySelectableData(
                    id: "3",
                    title: "Psalms for Today",
                    description: "Daily reflections on the Psalms",
                    lessonCount: 14,
                    imageURL: nil,
                    isSelected: false
                )
            )
        }
        .padding(20)
    }
}
