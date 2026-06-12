//
//  GroupPostCard.swift
//  MakeReady
//
//  Card component for displaying posts in a group feed.
//  Matches Figma designs: event post, text post, text + image post.
//

import SwiftUI

struct GroupPostCard: View {
    let post: GroupPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author row
            authorRow

            // Content text
            Text(post.content)
                .font(Typography.s13)
                .foregroundColor(.white)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            // Type-specific content
            switch post.type {
            case .event:
                eventCard
            case .welcome, .announcement:
                // Image if present (for welcome posts with cover image)
                if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                    postImage(url: url)
                }
            case .poll:
                pollContent
            case .video:
                videoContent
            }

            // Action bar (for text/image posts, not events)
            if post.type != .event {
                actionBar
            }
        }
        .padding(16)
    }

    // MARK: - Author Row

    private var authorRow: some View {
        HStack(spacing: 8) {
            // Avatar (40px)
            avatar

            // Name + timestamp
            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorName)
                    .font(Typography.s15Bold)
                    .foregroundColor(.white)

                relativeTimestamp
            }

            Spacer()
        }
    }

    private var avatar: some View {
        Avatar(
            imageURL: post.authorAvatarUrl,
            initials: initials(from: post.authorName),
            size: .md
        )
    }

    private var relativeTimestamp: some View {
        let (value, unit) = relativeTimeComponents(from: post.createdAt)
        return HStack(spacing: 4) {
            Text(value)
                .font(Typography.s11)
                .foregroundColor(.white.opacity(0.7))

            Text(unit)
                .font(Typography.s11)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 8) {
            // Left indicators
            HStack(spacing: 16) {
                // Views
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(Typography.s14)
                        .foregroundColor(.white)

                    Text("\(post.viewCount ?? 0)")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Shares/Reposts
                HStack(spacing: 8) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(Typography.s14)
                        .foregroundColor(.white)

                    Text("\(post.shareCount ?? 0)")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            // Right indicators
            HStack(spacing: 16) {
                // Bookmark
                Image(systemName: "bookmark")
                    .font(Typography.s14)
                    .foregroundColor(.white)

                // Share/Export
                Image(systemName: "square.and.arrow.up")
                    .font(Typography.s14)
                    .foregroundColor(.white)
            }
        }
        .frame(height: 18)
    }

    // MARK: - Event Card

    private var eventCard: some View {
        VStack(spacing: 0) {
            // Cover image
            if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    case .failure, .empty:
                        eventImagePlaceholder
                    @unknown default:
                        eventImagePlaceholder
                    }
                }
            } else {
                eventImagePlaceholder
            }

            // Event details row
            HStack(alignment: .top, spacing: 0) {
                // Date column
                if let eventDate = post.eventDate {
                    VStack(spacing: 0) {
                        Text(dayNumber(from: eventDate))
                            .font(Typography.s28)
                            .foregroundColor(.white)

                        Text(monthAbbrev(from: eventDate))
                            .font(Typography.s15Bold)
                            .foregroundColor(Color.brandPrimary)
                    }
                    .padding(16)
                }

                // Details column
                VStack(alignment: .leading, spacing: 0) {
                    // Event title
                    Text(post.eventTitle ?? post.title ?? "Event")
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    // Date and time
                    if let eventDate = post.eventDate {
                        Text(formatEventDateTime(eventDate))
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Attendee count
                    HStack(spacing: 4) {
                        Text("\(post.attendeeCount ?? 0)")
                            .font(Typography.s13Bold)
                            .foregroundColor(.white)

                        Text("people are going")
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(16)

                Spacer()
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(4)
    }

    private var eventImagePlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 200)
            .overlay(
                Image(systemName: "calendar")
                    .font(Typography.s32)
                    .foregroundColor(.white.opacity(0.3))
            )
    }

    // MARK: - Image Post

    private func postImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
            case .failure, .empty:
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(Typography.s32)
                            .foregroundColor(.white.opacity(0.3))
                    )
            @unknown default:
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 200)
            }
        }
    }

    // MARK: - Poll Content

    @ViewBuilder
    private var pollContent: some View {
        if let options = post.pollOptions {
            VStack(spacing: 8) {
                ForEach(options) { option in
                    pollOptionRow(option)
                }
            }
        }
    }

    private func pollOptionRow(_ option: PollOption) -> some View {
        let totalVotes = post.pollOptions?.reduce(0) { $0 + $1.voteCount } ?? 1
        let percentage = totalVotes > 0 ? Double(option.voteCount) / Double(totalVotes) : 0

        return HStack(spacing: 8) {
            // Selection indicator
            Circle()
                .strokeBorder(option.hasVoted ? Color.brandPrimary : Color.white.opacity(0.3), lineWidth: 2)
                .background(
                    Circle()
                        .fill(option.hasVoted ? Color.brandPrimary : Color.clear)
                )
                .frame(width: 18, height: 18)

            // Option text
            Text(option.text)
                .font(Typography.s14)
                .foregroundColor(.white)

            Spacer()

            // Vote count
            Text("\(option.voteCount)")
                .font(Typography.s14Medium)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.brandPrimary.opacity(0.2))
                    .frame(width: geometry.size.width * percentage)
            }
        )
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Video Content

    @ViewBuilder
    private var videoContent: some View {
        if post.videoUrl != nil {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 48)

                    Image(systemName: "play.fill")
                        .font(Typography.s20)
                        .foregroundColor(.white)
                }

                Text("Tap to play video")
                    .font(Typography.s14)
                    .foregroundColor(.white.opacity(0.5))

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private func relativeTimeComponents(from date: Date) -> (String, String) {
        let seconds = Int(-date.timeIntervalSinceNow)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            return ("\(days)", days == 1 ? "day ago" : "days ago")
        } else if hours > 0 {
            return ("\(hours)", hours == 1 ? "hour ago" : "hours ago")
        } else if minutes > 0 {
            return ("\(minutes)", minutes == 1 ? "minute ago" : "minutes ago")
        } else {
            return ("Just", "now")
        }
    }

    private func dayNumber(from date: Date) -> String {
        return DateFormatters.dayOfMonth.string(from: date)
    }

    private func monthAbbrev(from date: Date) -> String {
        return DateFormatters.monthAbbrev.string(from: date).uppercased()
    }

    private func formatEventDateTime(_ date: Date) -> String {
        return DateFormatters.weekdayFullMonthDayTime.string(from: date).replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 0) {
                // Text post
                GroupPostCard(post: GroupPost(
                    id: "1",
                    groupId: "g1",
                    authorId: "u1",
                    authorName: "Tony Stark",
                    authorAvatarUrl: "https://i.pravatar.cc/150?img=12",
                    type: .announcement,
                    content: "Being confident of this, that He who began a good work in you will carry it on to completion.\" Even when your week feels unfinished or messy, remember — God's not done. The same faithfulness that got you started will see you through. Keep showing up, even when it's tough. You're growing more than you realize.",
                    title: nil,
                    createdAt: Date().addingTimeInterval(-900),
                    updatedAt: Date(),
                    viewCount: 25,
                    shareCount: 1
                ))

                Divider()
                    .background(Color.white.opacity(0.1))

                // Text + Image post
                GroupPostCard(post: GroupPost(
                    id: "2",
                    groupId: "g1",
                    authorId: "u1",
                    authorName: "Tony Stark",
                    authorAvatarUrl: nil,
                    type: .announcement,
                    content: "Last night's burger hangout was exactly what we needed — good food, loud laughter, and real conversation that reminded us how much community matters. It's crazy how something as simple as fries and fellowship can recharge your week. Grateful for this group!",
                    title: nil,
                    imageUrl: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600",
                    createdAt: Date().addingTimeInterval(-50400),
                    updatedAt: Date(),
                    viewCount: 20,
                    shareCount: 0
                ))

                Divider()
                    .background(Color.white.opacity(0.1))

                // Event post
                GroupPostCard(post: GroupPost(
                    id: "3",
                    groupId: "g1",
                    authorId: "u1",
                    authorName: "Tony Stark",
                    authorAvatarUrl: "https://i.pravatar.cc/150?img=8",
                    type: .event,
                    content: "We are throwing a birthday party for Tony on Monday. RSVP today so we make sure to have enough food.",
                    title: nil,
                    imageUrl: "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=600",
                    createdAt: Date().addingTimeInterval(-900),
                    updatedAt: Date(),
                    eventDate: Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 28, hour: 19, minute: 0)),
                    eventLocation: "Downtown",
                    eventTitle: "Tony Stark's birthday",
                    attendeeCount: 7
                ))

                Divider()
                    .background(Color.white.opacity(0.1))

                // Welcome post
                GroupPostCard(post: GroupPost(
                    id: "4",
                    groupId: "g1",
                    authorId: nil,
                    authorName: "MakeReady",
                    authorAvatarUrl: nil,
                    type: .welcome,
                    content: "Young Professionals is beginning the Foundation study program! Your first lesson link will be texted to you on Monday, January 6 at 9:00 AM. Get ready for 30 days of growth together!",
                    title: "Foundation starts Monday!",
                    imageUrl: "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=600",
                    createdAt: Date().addingTimeInterval(-1800),
                    updatedAt: Date(),
                    viewCount: 15,
                    shareCount: 2
                ))
            }
        }
    }
}
