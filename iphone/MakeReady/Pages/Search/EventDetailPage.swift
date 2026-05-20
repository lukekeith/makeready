//
//  EventDetailPage.swift
//  MakeReady
//
//  Simple event detail view opened from global search results.
//

import SwiftUI

struct EventDetailPage: View {
    let eventId: String
    let title: String
    let subtitle: String?
    let imageURL: String?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            PageTitle.iconTitle(
                title: "Event",
                icon: "chevron.left",
                onIconTap: { onDismiss?() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Cover image
                    if let imageURL = imageURL, !imageURL.isEmpty,
                       let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(8)
                            default:
                                Color.white.opacity(0.06)
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // Title
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    // Location / date info
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin")
                                .font(.system(size: 14))
                                .foregroundColor(.white50)
                            Text(subtitle)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground)
    }
}

#Preview {
    EventDetailPage(
        eventId: "test",
        title: "Test Event",
        subtitle: "Downtown Church",
        imageURL: nil,
        onDismiss: {}
    )
}
