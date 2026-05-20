//
//  CardLessonActivity.swift
//  MakeReady
//
//  Unified lesson activity card for both study and video activities.
//  Two sizes: .default (current full card) and .small (compact two-line).
//

import SwiftUI

// MARK: - Size

enum CardLessonActivitySize {
    case `default`
    case small
}

// MARK: - Data

struct CardLessonActivityData: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let type: String?           // Display label (e.g. "Write", "Read")
    let rawActivityType: String? // Raw API type for ActivityStyle lookup (e.g. "USER_INPUT", "READ", "EXEGESIS")
    let imageStyle: CardImageStyle
    let metadata: [DataItem]
    let status: CardStatus?
    let isVideo: Bool
    let estimatedMinutes: Int?
    let onTap: (() -> Void)?

    init(
        id: String,
        title: String,
        description: String? = nil,
        type: String? = nil,
        rawActivityType: String? = nil,
        imageStyle: CardImageStyle,
        metadata: [DataItem] = [],
        status: CardStatus? = nil,
        isVideo: Bool = false,
        estimatedMinutes: Int? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = Self.stripHtml(title)
        self.description = description.map { Self.stripHtml($0) }
        self.type = type
        self.rawActivityType = rawActivityType
        self.imageStyle = imageStyle
        self.metadata = metadata
        self.status = status
        self.isVideo = isVideo
        self.estimatedMinutes = estimatedMinutes
        self.onTap = onTap
    }

    private static func stripHtml(_ text: String) -> String {
        guard text.contains("<") else { return text }
        var s = text
        s = s.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "</p>", with: " ")
        s = s.replacingOccurrences(of: "</div>", with: " ")
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&#39;", with: "'")
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Hashable (exclude closure)
    static func == (lhs: CardLessonActivityData, rhs: CardLessonActivityData) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.description == rhs.description
            && lhs.type == rhs.type && lhs.imageStyle == rhs.imageStyle
            && lhs.status == rhs.status && lhs.isVideo == rhs.isVideo
            && lhs.estimatedMinutes == rhs.estimatedMinutes
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - View

struct CardLessonActivity: View {
    let data: CardLessonActivityData
    let size: CardLessonActivitySize
    let showAnimatedBorder: Bool
    let randomizeBorderStart: Bool
    let cornerRadius: CGFloat

    @State private var borderRotation: Double = 0
    @State private var hasStartedAnimation = false

    init(
        data: CardLessonActivityData,
        size: CardLessonActivitySize = .default,
        showAnimatedBorder: Bool = false,
        randomizeBorderStart: Bool = true,
        cornerRadius: CGFloat = 4
    ) {
        self.data = data
        self.size = size
        self.showAnimatedBorder = showAnimatedBorder
        self.randomizeBorderStart = randomizeBorderStart
        self.cornerRadius = cornerRadius
    }

    private var isNew: Bool { data.status == .new }
    private var isPending: Bool { data.status == .pending }
    private var showBorder: Bool { showAnimatedBorder && (isNew || isPending) }

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            switch size {
            case .default:
                defaultLayout
            case .small:
                smallLayout
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Default Layout

    private var defaultLayout: some View {
        HStack(spacing: 16) {
            // Left: Text content
            VStack(alignment: .leading, spacing: 0) {
                if isNew {
                    newContent
                } else if data.isVideo {
                    videoContent
                } else {
                    studyContent
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer(minLength: 0)

            // Right: Image + optional time estimate
            VStack(spacing: 4) {
                imageView(width: 72, height: 72)
                if let minutes = data.estimatedMinutes, minutes > 0 {
                    Text(formattedEstimate(minutes))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(16)
        .frame(minHeight: 104)
        .background(cardBackgroundColor)
        .cornerRadius(cornerRadius)
        .overlay(animatedBorderOverlay)
        .onAppear(perform: startBorderAnimation)
    }

    // MARK: - Small Layout

    private var smallLayout: some View {
        HStack(spacing: 12) {
            // Left: Image (smaller)
            imageView(width: 40, height: 40)

            // Right: Two lines of text
            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let description = data.description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)

            if let minutes = data.estimatedMinutes, minutes > 0 {
                Text(formattedEstimate(minutes))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackgroundColor)
        .cornerRadius(cornerRadius)
        .overlay(animatedBorderOverlay)
        .onAppear(perform: startBorderAnimation)
    }

    // MARK: - Text Content Variants (Default Size)

    /// New/unconfigured: type label + purple action text
    private var newContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let type = data.type {
                Text(type)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            if let description = data.description {
                Text(description)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.brandPrimary)
                    .lineLimit(2)
            }
        }
    }

    /// Video: description (lighter) above title (bold)
    private var videoContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let description = data.description {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Text(data.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.top, data.description != nil ? 4 : 0)

            if !data.metadata.isEmpty {
                HStack(spacing: 16) {
                    ForEach(data.metadata) { item in
                        DataComponent(item: item)
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    /// Study: title (bold) above description
    private var studyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(data.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            if let description = data.description {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            if !data.metadata.isEmpty {
                HStack(spacing: 16) {
                    ForEach(data.metadata) { item in
                        DataComponent(item: item)
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Image

    @ViewBuilder
    private func imageView(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            switch data.imageStyle {
            case .photo(let imageURL):
                if imageURL.hasPrefix("asset://") {
                    let assetName = imageURL.replacingOccurrences(of: "asset://", with: "")
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .cornerRadius(size == .small ? 6 : 8)
                } else {
                    CachedCardImage(
                        url: imageURL.mediumImageUrl,
                        fallbackUrl: imageURL,
                        width: width,
                        height: height,
                        fallback: { iconFallback(width: width, height: height) }
                    )
                }

            case .icon(let systemName, let backgroundColor, let foregroundColor):
                iconView(
                    systemName: systemName,
                    backgroundColor: backgroundColor,
                    foregroundColor: foregroundColor,
                    width: width,
                    height: height
                )

            case .dateDisplay, .timeDisplay:
                iconFallback(width: width, height: height)
            }

            // Play icon overlay for video (not in .new or .small)
            if data.isVideo && !isNew && size == .default {
                VStack {
                    Spacer()
                    Image("IconVideoPlay")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func iconFallback(width: CGFloat, height: CGFloat) -> some View {
        let notReady = isNew || isPending
        let radius: CGFloat = size == .small ? 6 : 8
        let brandColor = ActivityStyle.color(forRawType: data.rawActivityType)

        if notReady {
            Color.clear
                .overlay(
                    Image(systemName: data.isVideo ? "play.circle.fill" : "book.fill")
                        .font(.system(size: size == .small ? 16 : 24))
                        .foregroundColor(brandColor)
                )
                .frame(width: width, height: height)
                .cornerRadius(radius)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(brandColor, lineWidth: 1.5)
                )
        } else {
            Color.iconContainerBackground
                .overlay(
                    Image(systemName: data.isVideo ? "play.circle.fill" : "book.fill")
                        .font(.system(size: size == .small ? 16 : 24))
                        .foregroundColor(.white)
                )
                .frame(width: width, height: height)
                .cornerRadius(radius)
        }
    }

    @ViewBuilder
    private func activityIconImage(name: String, iconSize: CGFloat) -> some View {
        if name.hasPrefix("Icon") {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
        } else {
            Image(systemName: name)
                .font(.system(size: iconSize))
        }
    }

    private func iconView(
        systemName: String,
        backgroundColor: Color?,
        foregroundColor: Color?,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let notReady = isNew || isPending
        let radius: CGFloat = size == .small ? 6 : 8
        let iconSize: CGFloat = size == .small ? 16 : 24
        let brandColor = ActivityStyle.color(forRawType: data.rawActivityType)

        return Group {
            if notReady {
                Color.clear
                    .overlay(
                        activityIconImage(name: systemName.isEmpty ? "IconActivityRead" : systemName, iconSize: data.isVideo && isNew ? (size == .small ? 16 : 32) : iconSize)
                            .foregroundColor(brandColor)
                    )
                    .frame(width: width, height: height)
                    .cornerRadius(radius)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(brandColor, lineWidth: 1.5)
                    )
            } else {
                (backgroundColor ?? Color.iconContainerBackground)
                    .overlay(
                        activityIconImage(name: systemName.isEmpty ? "IconActivityRead" : systemName, iconSize: iconSize)
                            .foregroundColor(foregroundColor ?? .white)
                    )
                    .frame(width: width, height: height)
                    .cornerRadius(radius)
            }
        }
    }

    // MARK: - Time Estimate

    private func formattedEstimate(_ minutes: Int) -> String {
        if minutes > 99 {
            return ">99 min"
        } else {
            return "\(minutes) min"
        }
    }

    // MARK: - Background & Border

    private var cardBackgroundColor: Color {
        if showAnimatedBorder {
            return Color.cardBackground
        }
        if isNew || isPending {
            return Color.backgroundPurple
        }
        return Color.cardBackground
    }

    @ViewBuilder
    private var animatedBorderOverlay: some View {
        if showBorder {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#6c47ff"),
                            Color(hex: "#6c47ff").opacity(0.2),
                            Color(hex: "#6c47ff")
                        ]),
                        center: .center,
                        angle: .degrees(borderRotation)
                    ),
                    lineWidth: 2
                )
        }
    }

    private func startBorderAnimation() {
        guard showBorder, !hasStartedAnimation else { return }
        let startOffset = randomizeBorderStart ? Double.random(in: 0..<360) : 0
        borderRotation = startOffset
        hasStartedAnimation = true
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            borderRotation = startOffset + 360
        }
    }
}

// MARK: - Preview

#Preview("Default - Study") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 12) {
            // Configured READ activity
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "1",
                    title: "Romans 1:1-5",
                    description: "Scripture, Observation, Application, Prayer",
                    type: "READ",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "READ"),
                        backgroundColor: ActivityStyle.color(forRawType: "READ"),
                        foregroundColor: ActivityStyle.iconColor(forRawType: "READ")
                    ),
                    status: .confirmed
                )
            )

            // Configured USER_INPUT activity
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "1b",
                    title: "Journal Entry",
                    description: "Write your reflections",
                    type: "USER_INPUT",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "USER_INPUT"),
                        backgroundColor: ActivityStyle.color(forRawType: "USER_INPUT"),
                        foregroundColor: ActivityStyle.iconColor(forRawType: "USER_INPUT")
                    ),
                    status: .confirmed
                )
            )

            // Configured EXEGESIS activity
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "1c",
                    title: "Ephesians 2:8-9",
                    description: "Exegetical analysis",
                    type: "EXEGESIS",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "EXEGESIS"),
                        backgroundColor: ActivityStyle.color(forRawType: "EXEGESIS"),
                        foregroundColor: ActivityStyle.iconColor(forRawType: "EXEGESIS")
                    ),
                    status: .confirmed
                )
            )

            // New READ (unconfigured)
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "2",
                    title: "READ",
                    description: "Select passage",
                    type: "READ",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "READ"),
                        backgroundColor: nil,
                        foregroundColor: ActivityStyle.color(forRawType: "READ")
                    ),
                    status: .new
                ),
                showAnimatedBorder: true
            )

            // New USER_INPUT (unconfigured)
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "2b",
                    title: "USER_INPUT",
                    description: "Configure prompt",
                    type: "USER_INPUT",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "USER_INPUT"),
                        backgroundColor: nil,
                        foregroundColor: ActivityStyle.color(forRawType: "USER_INPUT")
                    ),
                    status: .new
                ),
                showAnimatedBorder: true
            )
        }
        .padding(20)
    }
}

#Preview("Default - Video") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 12) {
            // Configured video with thumbnail
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "3",
                    title: "Sunday Sermon: Faith in Action",
                    description: "5:30",
                    type: "VIDEO",
                    imageStyle: .photo(imageURL: "https://picsum.photos/116/116"),
                    status: .confirmed,
                    isVideo: true
                )
            )

            // Configured YOUTUBE with thumbnail
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "3b",
                    title: "Bible Project: Romans Overview",
                    description: "12:45",
                    type: "YOUTUBE",
                    imageStyle: .photo(imageURL: "https://picsum.photos/116/116"),
                    status: .confirmed,
                    isVideo: true
                )
            )

            // New VIDEO (unconfigured)
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "4",
                    title: "VIDEO",
                    description: "Select video",
                    type: "VIDEO",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "VIDEO"),
                        backgroundColor: nil,
                        foregroundColor: ActivityStyle.color(forRawType: "VIDEO")
                    ),
                    status: .new,
                    isVideo: true
                ),
                showAnimatedBorder: true
            )

            // New YOUTUBE (unconfigured)
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "4b",
                    title: "YOUTUBE",
                    description: "Add YouTube URL",
                    type: "YOUTUBE",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "YOUTUBE"),
                        backgroundColor: nil,
                        foregroundColor: ActivityStyle.color(forRawType: "YOUTUBE")
                    ),
                    status: .new,
                    isVideo: true
                ),
                showAnimatedBorder: true
            )
        }
        .padding(20)
    }
}

#Preview("Small") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 8) {
            // Small READ with time estimate
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "5",
                    title: "Romans 1:1-5",
                    description: "Scripture, Observation, Application, Prayer",
                    type: "READ",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "READ"),
                        backgroundColor: ActivityStyle.color(forRawType: "READ"),
                        foregroundColor: ActivityStyle.iconColor(forRawType: "READ")
                    ),
                    status: .confirmed,
                    estimatedMinutes: 15
                ),
                size: .small
            )

            // Small USER_INPUT with time estimate
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "5b",
                    title: "Reflection Journal",
                    description: "Write your thoughts",
                    type: "USER_INPUT",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "USER_INPUT"),
                        backgroundColor: ActivityStyle.color(forRawType: "USER_INPUT"),
                        foregroundColor: ActivityStyle.iconColor(forRawType: "USER_INPUT")
                    ),
                    status: .confirmed,
                    estimatedMinutes: 10
                ),
                size: .small
            )

            // Small EXEGESIS with time estimate
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "5c",
                    title: "Ephesians 2:8-9",
                    description: "Exegetical analysis",
                    type: "EXEGESIS",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "EXEGESIS"),
                        backgroundColor: ActivityStyle.color(forRawType: "EXEGESIS"),
                        foregroundColor: ActivityStyle.iconColor(forRawType: "EXEGESIS")
                    ),
                    status: .confirmed,
                    estimatedMinutes: 20
                ),
                size: .small
            )

            // Small video with thumbnail + time estimate
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "6",
                    title: "Sunday Sermon: Faith in Action",
                    description: "5:30 · Sermons",
                    type: "VIDEO",
                    imageStyle: .photo(imageURL: "https://picsum.photos/80/80"),
                    status: .confirmed,
                    isVideo: true,
                    estimatedMinutes: 5
                ),
                size: .small
            )

            // Small unconfigured READ
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "7",
                    title: "READ",
                    description: "Select passage",
                    type: "READ",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "READ"),
                        backgroundColor: nil,
                        foregroundColor: ActivityStyle.color(forRawType: "READ")
                    ),
                    status: .new
                ),
                size: .small,
                showAnimatedBorder: true
            )

            // Small unconfigured EXEGESIS
            CardLessonActivity(
                data: CardLessonActivityData(
                    id: "7b",
                    title: "EXEGESIS",
                    description: "Select passage",
                    type: "EXEGESIS",
                    imageStyle: .icon(
                        systemName: ActivityStyle.icon(forRawType: "EXEGESIS"),
                        backgroundColor: nil,
                        foregroundColor: ActivityStyle.color(forRawType: "EXEGESIS")
                    ),
                    status: .new
                ),
                size: .small,
                showAnimatedBorder: true
            )
        }
        .padding(20)
    }
}
