//
//  Avatar.swift
//  MakeReady
//
//  Reusable avatar component with multiple sizes and fallback states
//

import SwiftUI

// MARK: - Avatar Size Variants

enum AvatarSize {
    case xs      // 24px
    case sm      // 32px
    case md      // 40px
    case lg      // 48px
    case xl      // 64px
    case xxl     // 96px

    var dimension: CGFloat {
        switch self {
        case .xs: return 24
        case .sm: return 32
        case .md: return 40
        case .lg: return 48
        case .xl: return 64
        case .xxl: return 96
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .xs: return 10
        case .sm: return 13
        case .md: return 16
        case .lg: return 19
        case .xl: return 26
        case .xxl: return 38
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .xs: return 12
        case .sm: return 16
        case .md: return 20
        case .lg: return 24
        case .xl: return 32
        case .xxl: return 48
        }
    }
}

// MARK: - Avatar Component

struct Avatar: View {
    let imageURL: String?
    let imageData: Data? // For real contacts from device
    let initials: String?
    let size: AvatarSize

    // For accessibility
    let accessibilityLabel: String?

    // Computed initials (max 2 characters, uppercase)
    private var displayInitials: String {
        guard let initials = initials else { return "" }
        return String(initials.prefix(2)).uppercased()
    }

    // Background gradient for initials
    private var initialsGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandPrimary.opacity(0.6),
                Color.brandPrimary.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    init(
        imageURL: String? = nil,
        imageData: Data? = nil,
        initials: String? = nil,
        size: AvatarSize = .md,
        accessibilityLabel: String? = nil
    ) {
        self.imageURL = imageURL
        self.imageData = imageData
        self.initials = initials
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Group {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                // Real contact photo from device
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let imageURL = imageURL, let url = URL(string: imageURL) {
                // Profile photo from URL
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        // Fallback to initials or icon if image fails
                        fallbackContent
                    @unknown default:
                        fallbackContent
                    }
                }
            } else {
                // No image URL or data - show fallback
                fallbackContent
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
        .accessibilityLabel(accessibilityLabel ?? "User avatar")
    }

    @ViewBuilder
    private var fallbackContent: some View {
        if let initials = initials, !initials.isEmpty {
            // Initials fallback
            Circle()
                .fill(initialsGradient)
                .overlay(
                    Text(displayInitials)
                        .font(.system(size: size.fontSize, weight: .bold))
                        .foregroundColor(.white)
                )
        } else {
            // Icon fallback
            Circle()
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: size.iconSize))
                        .foregroundColor(.white.opacity(0.2))
                )
        }
    }
}

// MARK: - Convenience Initializers

extension Avatar {
    // Create from full name
    init(
        imageURL: String? = nil,
        imageData: Data? = nil,
        firstName: String?,
        lastName: String?,
        size: AvatarSize = .md
    ) {
        let initials = Self.generateInitials(firstName: firstName, lastName: lastName)
        let accessibilityLabel = Self.generateAccessibilityLabel(firstName: firstName, lastName: lastName)

        self.init(
            imageURL: imageURL,
            imageData: imageData,
            initials: initials,
            size: size,
            accessibilityLabel: accessibilityLabel
        )
    }

    // Helper to generate initials from first/last name
    private static func generateInitials(firstName: String?, lastName: String?) -> String? {
        let first = firstName?.prefix(1).uppercased() ?? ""
        let last = lastName?.prefix(1).uppercased() ?? ""

        if !first.isEmpty && !last.isEmpty {
            return first + last
        } else if !first.isEmpty {
            return first
        } else if !last.isEmpty {
            return last
        } else {
            return nil
        }
    }

    // Helper to generate accessibility label
    private static func generateAccessibilityLabel(firstName: String?, lastName: String?) -> String {
        let name = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? "User avatar" : "\(name)'s avatar"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 32) {
                // Size variants with photo
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sizes - With Photo")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Avatar(
                                imageURL: "https://i.pravatar.cc/150?img=5",
                                initials: "SJ",
                                size: .xs
                            )
                            Text("xs (24)")
                                .font(Typography.s10)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        VStack(spacing: 4) {
                            Avatar(
                                imageURL: "https://i.pravatar.cc/150?img=5",
                                initials: "SJ",
                                size: .sm
                            )
                            Text("sm (32)")
                                .font(Typography.s10)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        VStack(spacing: 4) {
                            Avatar(
                                imageURL: "https://i.pravatar.cc/150?img=5",
                                initials: "SJ",
                                size: .md
                            )
                            Text("md (40)")
                                .font(Typography.s10)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        VStack(spacing: 4) {
                            Avatar(
                                imageURL: "https://i.pravatar.cc/150?img=5",
                                initials: "SJ",
                                size: .lg
                            )
                            Text("lg (48)")
                                .font(Typography.s10)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        VStack(spacing: 4) {
                            Avatar(
                                imageURL: "https://i.pravatar.cc/150?img=5",
                                initials: "SJ",
                                size: .xl
                            )
                            Text("xl (64)")
                                .font(Typography.s10)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        VStack(spacing: 4) {
                            Avatar(
                                imageURL: "https://i.pravatar.cc/150?img=5",
                                initials: "SJ",
                                size: .xxl
                            )
                            Text("xxl (96)")
                                .font(Typography.s10)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }

                // Initials variants
                VStack(alignment: .leading, spacing: 16) {
                    Text("Initials - Two Letters")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        Avatar(initials: "AB", size: .xs)
                        Avatar(initials: "CD", size: .sm)
                        Avatar(initials: "EF", size: .md)
                        Avatar(initials: "GH", size: .lg)
                        Avatar(initials: "IJ", size: .xl)
                        Avatar(initials: "KL", size: .xxl)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Initials - One Letter")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        Avatar(initials: "A", size: .xs)
                        Avatar(initials: "B", size: .sm)
                        Avatar(initials: "C", size: .md)
                        Avatar(initials: "D", size: .lg)
                        Avatar(initials: "E", size: .xl)
                        Avatar(initials: "F", size: .xxl)
                    }
                }

                // Icon fallback
                VStack(alignment: .leading, spacing: 16) {
                    Text("Icon Fallback (No Photo or Initials)")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        Avatar(size: .xs)
                        Avatar(size: .sm)
                        Avatar(size: .md)
                        Avatar(size: .lg)
                        Avatar(size: .xl)
                        Avatar(size: .xxl)
                    }
                }

                // Convenience initializer with names
                VStack(alignment: .leading, spacing: 16) {
                    Text("Using First/Last Name")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Avatar(
                                imageURL: "https://i.pravatar.cc/150?img=12",
                                firstName: "John",
                                lastName: "Doe",
                                size: .xl
                            )
                            Text("John Doe\n(with photo)")
                                .font(Typography.s11)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 8) {
                            Avatar(
                                firstName: "Jane",
                                lastName: "Smith",
                                size: .xl
                            )
                            Text("Jane Smith\n(initials)")
                                .font(Typography.s11)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 8) {
                            Avatar(
                                firstName: nil,
                                lastName: nil,
                                size: .xl
                            )
                            Text("Unknown\n(icon)")
                                .font(Typography.s11)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}
