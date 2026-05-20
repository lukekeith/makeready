//
//  DataComponent.swift
//  MakeReady
//
//  Small metadata display component used within Card components
//

import SwiftUI



struct DataComponent: View {
    let item: DataItem

    private var foregroundColor: Color {
        item.isPurple ? Color(hex: "#6c47ff") : .white
    }

    var body: some View {
        HStack(spacing: 4) {
            switch item.type {
            case .icon:
                // Icon + value variant
                if let iconName = item.iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(foregroundColor)
                        .frame(width: 14, height: 14)
                }

                Text(item.value)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(foregroundColor)

            case .number:
                // Number + label variant
                Text(item.value)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(foregroundColor)

                if let label = item.label {
                    Text(label)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(foregroundColor.opacity(0.7))
                }

            case .labelValue:
                // Label + value variant (11px, label 50% white, value 70% white)
                if let label = item.label {
                    Text(label)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text(item.value)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))

            case .badge:
                // Small capsule badge (e.g., Published / Draft)
                Text(item.value)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(item.badgeTextColor ?? .white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(item.badgeColor ?? Color(hex: "#242A3E"))
                    )

            case .loading:
                // Skeleton shimmer placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: item.loadingWidth, height: 14)
                    .shimmer()
            }
        }
        .frame(height: 18)
    }
}

// MARK: - Skeleton Loading State

/// Skeleton placeholder for DataComponent while loading
/// Shows a shimmer animation matching the size of the actual component
struct SkeletonDataComponent: View {
    /// Approximate width of the content (e.g., "3 enrollments" ≈ 80px)
    var width: CGFloat = 80

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.1))
            .frame(width: width, height: 14)
            .shimmer()
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Icon Type")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 16) {
                    DataComponent(item: DataItem(icon: "clock", value: "28"))
                    DataComponent(item: DataItem(icon: "person.2", value: "15"))
                    DataComponent(item: DataItem(icon: "eye", value: "1.2K"))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Number Type")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 16) {
                    DataComponent(item: DataItem(number: "28", label: "Members"))
                    DataComponent(item: DataItem(number: "15", label: "Participants"))
                    DataComponent(item: DataItem(number: "1.2K", label: "views"))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Skeleton Loading State")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 16) {
                    DataComponent(item: DataItem(icon: "calendar", value: "30 days"))
                    SkeletonDataComponent(width: 80)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Mixed in Row (16px gaps)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 16) {
                    DataComponent(item: DataItem(icon: "clock", value: "10:00 AM"))
                    DataComponent(item: DataItem(icon: "mappin", value: "Main Chapel"))
                    DataComponent(item: DataItem(number: "28", label: "Members"))
                }
            }
        }
        .padding(20)
    }
}
