//
//  CardGroup.swift
//  MakeReady
//
//  Group card component with Row and Mini layouts
//

import SwiftUI


struct CardGroup: View {
    let data: CardGroupData
    let cornerRadius: CGFloat

    init(data: CardGroupData, cornerRadius: CGFloat = 4) {
        self.data = data
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            HStack(spacing: 16) {
                // Left: Circular image (72×72)
                imageView
                    .frame(width: 72, height: 72)

                // Right: Content
                VStack(alignment: .leading, spacing: 0) {
                    // Title + optional subtitle (e.g. the group leader's name)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if let subtitle = data.subtitle {
                            Text(subtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }

                    // Metadata row
                    HStack(spacing: 16) {
                        ForEach(data.metadata) { item in
                            DataComponent(item: item)
                        }
                    }
                    .padding(.top, 16)
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(height: 104)  // 72 + 16*2 padding
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Image View

    @ViewBuilder
    private var imageView: some View {
        ZStack {
            // Base image (circular)
            switch data.imageStyle {
            case .photo(let imageURL):
                CachedCardImage(
                    url: imageURL.mediumImageUrl,
                    fallbackUrl: imageURL,
                    width: 72,
                    height: 72,
                    clipCircle: true,
                    placeholder: { loadingPlaceholder },
                    fallback: { iconFallback }
                )

            case .icon(_, _, _):
                iconFallback

            case .dateDisplay, .timeDisplay:
                // Groups don't use date/time display, but handle it gracefully
                iconFallback
            }

            // Selected state overlay (always present, animated opacity)
            ZStack {
                // Purple 80% overlay
                Circle()
                    .fill(Color(hex: "#6c47ff").opacity(0.8))
                    .frame(width: 72, height: 72)

                // Checkmark icon (24×24)
                Image("IconCheckmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
            }
            .opacity(data.isSelected ? 1 : 0)
            .animation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2), value: data.isSelected)

            // iOS app-icon-style red count badge for pending member requests.
            // Hidden during the selected-state purple overlay so the two
            // indicators never compete.
            if data.pendingRequestCount > 0 && !data.isSelected {
                Text(badgeText(for: data.pendingRequestCount))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, data.pendingRequestCount > 9 ? 6 : 0)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Capsule().fill(Color.red))
                    .overlay(Capsule().stroke(Color.cardBackground, lineWidth: 2))
                    .frame(width: 72, height: 72, alignment: .topTrailing)
                    .offset(x: 4, y: -4)
            }
        }
    }

    /// Cap the displayed count at "99+" iOS-style so the badge doesn't grow
    /// arbitrarily wide for very large numbers.
    private func badgeText(for count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }

    private var loadingPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 72, height: 72)
    }

    private var iconFallback: some View {
        Circle()
            .fill(Color.iconContainerBackground)
            .frame(width: 72, height: 72)
            .overlay(
                Image("IconGroup")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                    .opacity(data.isSelected ? 0 : 1)
                    .animation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2), value: data.isSelected)
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            Text("Group Cards - Row")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            CardGroup(
                data: CardGroupData(
                    id: "group-1",
                    title: "Young Professionals",
                    imageStyle: .photo(imageURL: "https://picsum.photos/72/72"),
                    metadata: [
                        DataItem(number: "28", label: "Members")
                    ],
                    isSelected: false,
                    onTap: nil
                )
            )

            CardGroup(
                data: CardGroupData(
                    id: "group-2",
                    title: "Bible Study Group",
                    imageStyle: .icon(systemName: "person.2.fill", backgroundColor: .purple),
                    metadata: [
                        DataItem(number: "15", label: "Members")
                    ],
                    isSelected: true,
                    onTap: nil
                )
            )
        }
        .padding(20)
    }
}
