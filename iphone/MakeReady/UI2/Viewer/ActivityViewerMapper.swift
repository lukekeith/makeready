import SwiftUI
import UIKit

/// text-activity D9/D11/D23/D25 and §iphone "Viewer": the viewer's pure mapping. A loaded lesson
/// version, the engine's positions and the hosts' playback become `ActivitiesPlayerScreen.State`.
///
/// The page list is the version's activities in lesson order plus the completion page (D23). Every
/// page is given to the screen; the screen draws only the anchor and its neighbours (01 §2), and the
/// container mounts players only for `mountedPages`.
///
/// Units: the engine works in points; the screen's `inner` and object geometry are in width units,
/// `u = viewportWidth / 440` (02 §4).
enum ActivityViewerMapper {

    /// What the hosts hold that the screen draws: each video page's playback (by lesson index), the
    /// rail's visibility (01 §8) and the rail's capsule morph, −1...1 (C-133 `morphProgress`).
    struct Playback: Equatable {
        struct Video: Equatable {
            /// Seconds.
            var position: Double = 0
            var duration: Double = 0
            var playing = false
            var buffering = false
        }

        var videos: [Int: Video] = [:]
        var railVisible = true
        var morph: Double = 0

        static let idle = Playback()
    }

    /// One page of the stack: an activity, or the completion page that closes every lesson (D23).
    enum Page: Equatable {
        case activity(ContentActivity)
        case end
    }

    /// 02 §4: the reference canvas.
    static let referenceWidth = 440.0
    static let referenceHeight = 956.0

    // MARK: - Pages

    /// The activities in lesson order, then the completion page.
    static func pages(_ payload: LessonVersionPayload) -> [Page] {
        payload.activities.sorted { $0.position < $1.position }.map(Page.activity) + [.end]
    }

    /// §iphone "Viewer" (01 §2): the active page and one neighbour each side.
    static func mountedPages(active: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let clamped = min(max(active, 0), count - 1)
        return Array(max(0, clamped - 1)...min(count - 1, clamped + 1))
    }

    /// The page an activity id opens on (D22); the first page when it isn't in the version.
    static func pageIndex(of activityId: String, in payload: LessonVersionPayload) -> Int {
        pages(payload).firstIndex { if case .activity(let a) = $0 { return a.id == activityId } else { return false } } ?? 0
    }

    // MARK: - State

    /// The screen's state for one frame. `viewport` is the viewport's width in points (the source of
    /// `u`); the container sets the safe-area insets and the sheet on top.
    static func state(payload: LessonVersionPayload, engine: ViewerEngine, viewport: Double,
                      playback: Playback) -> ActivitiesPlayerScreen.State {
        let unit = max(viewport, 1) / referenceWidth
        let pages = pages(payload)
        let last = pages.count - 1
        var s = empty
        s.pageCount = pages.count
        s.anchor = engine.anchor
        // ViewerEngine: past the last page the drag follows the finger without limit; the completion
        // page holds still instead (D23: Close is the way out).
        s.drag = engine.anchor >= last ? min(engine.drag, 0) : engine.drag
        s.activePage = engine.activePage
        s.morphProgress = playback.morph
        s.thumbFraction = engine.thumbFraction(page: engine.activePage)
        s.railVisible = playback.railVisible
        s.topAction = pages.indices.contains(engine.activePage) ? topAction(pages[engine.activePage]) : "none"

        for (index, page) in pages.enumerated() {
            s.pageIndexes.append(index)
            s.inner.append((engine.inner.indices.contains(index) ? engine.inner[index] : 0) / unit)
            switch page {
            case .end:
                s.pageKinds.append("end")
                s.appendPage(title: payload.version.title ?? "", background: .default, media: payload.media)
            case .activity(let activity):
                append(activity, index: index, to: &s, media: payload.media, playback: playback)
            }
        }
        return s
    }

    /// The state before a version has loaded, or when it couldn't (§3 Load failed).
    static func emptyState(loadFailed: Bool) -> ActivitiesPlayerScreen.State {
        var s = empty
        s.loadFailed = loadFailed
        s.railVisible = false
        s.topAction = "none"
        return s
    }

    /// C-134's top action: the document's `chrome.topAction` (02 §2), else 01 §9's per-kind default —
    /// `menu` on video pages, `share` on the rest, none on the completion page.
    static func topAction(_ page: Page) -> String {
        guard case .activity(let activity) = page else { return "none" }
        if case .string(let action)? = activity.document.raw[path: ["chrome", "topAction"]],
           ["share", "menu", "none"].contains(action) {
            return action
        }
        switch activity.document.renderable {
        case .video, .youtube: return "menu"
        default: return "share"
        }
    }

    // MARK: - Media

    /// §Contract: a video document's media row, by the id the document names.
    static func videoEntry(_ video: VideoContent, media: [String: MediaMapEntry]) -> MediaMapEntry? {
        media[video.videoId]
    }

    /// Each video page's stream, by lesson index.
    static func videoSources(_ payload: LessonVersionPayload) -> [Int: URL] {
        var sources: [Int: URL] = [:]
        for (index, page) in pages(payload).enumerated() {
            guard case .activity(let activity) = page, case .video(let video) = activity.document.renderable,
                  let entry = videoEntry(video, media: payload.media),
                  let url = URL(string: entry.playbackUrl ?? entry.url) else { continue }
            sources[index] = url
        }
        return sources
    }

    /// The YouTube page at `index`, if it is one.
    static func youtube(at index: Int, in payload: LessonVersionPayload) -> YouTubeContent? {
        let pages = pages(payload)
        guard pages.indices.contains(index), case .activity(let activity) = pages[index],
              case .youtube(let content) = activity.document.renderable else { return nil }
        return content
    }

    /// Whether the page at `index` is a video page (C-135, whose control row claims its touch).
    static func isVideoPage(_ index: Int, in payload: LessonVersionPayload) -> Bool {
        let pages = pages(payload)
        guard pages.indices.contains(index), case .activity(let activity) = pages[index],
              case .video = activity.document.renderable else { return false }
        return true
    }

    /// The action `id` on the page at `index` (the screen reports only the id).
    static func action(_ id: String, onPage index: Int, in payload: LessonVersionPayload) -> ActivityAction? {
        let pages = pages(payload)
        guard pages.indices.contains(index), case .activity(let activity) = pages[index] else { return nil }
        return activity.document.actions.first { $0.id == id }
    }

    // MARK: - Page heights (02 §4, for the engine)

    /// Each page's height in points on a `size` viewport: a canvas or write page by its content's
    /// box (`ActivityCanvas.placement`, the screen's own function), every other page the viewport.
    static func pageHeights(_ payload: LessonVersionPayload, size: CGSize) -> [Double] {
        let unit = max(size.width, 1) / referenceWidth
        return pages(payload).map { page in
            guard case .activity(let activity) = page else { return Double(size.height) }
            let document = activity.document
            let pinned = document.actions.contains { $0.placement == .pinned }
            let inline = document.actions.filter { $0.placement == .inline }.count
            let extent: ClosedRange<CGFloat>?
            let anchor: ActivityCanvas<AnyView>.VerticalAnchor
            switch document.renderable {
            case .canvas(let canvas):
                extent = contentExtent(objects: objects(canvas: canvas, raw: document.raw), write: false,
                                       inlineRows: inline, unit: unit)
                anchor = canvas.verticalAnchor == "top" ? .top : .center
            case .write(let write):
                extent = contentExtent(objects: [(write.prompt, label(document.raw[path: ["content", "prompt"]]))],
                                       write: true, inlineRows: inline, unit: unit)
                anchor = .center
            default:
                return Double(size.height)
            }
            let placed = ActivityCanvas<AnyView>.placement(viewportHeight: size.height, contentExtent: extent,
                                                           verticalAnchor: anchor, pinnedAction: pinned, unit: unit)
            return Double(placed.pageHeight * unit)
        }
    }

    /// `ActivitiesPlayerScreen`'s §2 Canvas placement, from measured text: the objects' rotated,
    /// scaled box, then the write group 24 wu under the prompt, then the inline rows. In wu.
    static func contentExtent(objects: [(TextObject, Bool)], write: Bool, inlineRows: Int,
                              unit: CGFloat) -> ClosedRange<CGFloat>? {
        var top = CGFloat.infinity
        var bottom = -CGFloat.infinity
        for (object, labeled) in objects {
            let radians = object.transform.rotation * .pi / 180
            let width = CGFloat(layoutWidth(object)) * object.transform.scale
            let height = CGFloat(textHeight(object, labeled: labeled)) * object.transform.scale
            let half = (abs(width * sin(radians)) + abs(height * cos(radians))) / 2
            top = min(top, object.transform.y - half)
            bottom = max(bottom, object.transform.y + half)
        }
        if write {
            let fieldTop = top <= bottom ? bottom + Layout.writeFieldGap : CGFloat(referenceHeight) / 2
            top = min(top, fieldTop)
            bottom = fieldTop + Layout.writeFieldHeight + Layout.writeCaptionGap + Layout.captionLineHeight
        }
        guard top <= bottom else { return nil }
        var rowTop = bottom + Layout.inlineGap - Layout.inlineGlyphInset / unit
        for _ in 0..<inlineRows {
            bottom = rowTop + Layout.inlineRowHeight / unit
            rowTop = bottom + Layout.inlinePitch
        }
        return top...bottom
    }

    /// One object's laid-out text height in wu: its text set in its face at its size, wrapped at its
    /// layout width (C-092 draws at the face's natural line height). A label box adds 8 / 4 wu padding.
    static func textHeight(_ object: TextObject, labeled: Bool) -> Double {
        let font = uiFont(key: object.font, weight: ActivitiesEditorMapper.weightName(object.weight), size: object.size)
        let width = max(1, layoutWidth(object) - (labeled ? 2 * Layout.labelPaddingX : 0))
        let text = object.text.isEmpty ? " " : object.text
        let box = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                  options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                  attributes: [.font: font], context: nil)
        return Double(ceil(box.height)) + (labeled ? 2 * Layout.labelPaddingY : 0)
    }

    // MARK: - Internals

    /// `ActivitiesPlayerScreen` §2's flagged literals that the page height depends on, in wu unless
    /// marked (the screen keeps its own copies private).
    private enum Layout {
        static let slotWidth: Double = 392
        static let writeFieldGap: CGFloat = 24
        static let writeFieldHeight: CGFloat = 120
        static let writeCaptionGap: CGFloat = 8
        static var captionLineHeight: CGFloat { Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size }
        static let inlineGap: CGFloat = 58
        /// Points.
        static let inlineGlyphInset: CGFloat = 10
        static let inlineRowHeight: CGFloat = 44
        static let inlinePitch: CGFloat = 24
        /// C-092 §2 Label: box padding 8 / 4 wu.
        static let labelPaddingX: Double = 8
        static let labelPaddingY: Double = 4
    }

    private static let empty = ActivitiesPlayerScreen.State(
        pageCount: 0, anchor: 0, drag: 0, activePage: 0, morphProgress: 0, thumbFraction: nil,
        railVisible: true, topAction: "share", topInset: 0, bottomInset: 0,
        pageIndexes: [], pageKinds: [], inner: [], pageColorHexes: [], pageImageURLs: [],
        pageImageFocalXs: [], pageImageFocalYs: [], pageWashHexes: [], pageWashOpacities: [],
        pageVerticalAnchors: [], pageTitles: [], pageBodies: [], pagePlaceholders: [],
        pageCaptionLines: [], pagePresenterNames: [], pagePresenterImageURLs: [], pagePresenterInitials: [],
        pageReferences: [], pageRemainingTimes: [], pageProgresses: [], pagePlaying: [], pageBuffering: [],
        objectPages: [], objectTexts: [], objectFonts: [], objectColors: [], objectWeights: [], objectSizes: [],
        objectAlignments: [], objectLabels: [], objectListStyles: [], objectStartNumbers: [],
        objectAnimations: [], objectAnimationLoops: [], objectEffects: [], objectXs: [], objectYs: [],
        objectScales: [], objectRotations: [], objectWidths: [], objectHeights: [],
        markObjects: [], markStarts: [], markEnds: [], markKinds: [], markHrefs: [],
        highlightObjects: [], highlightStarts: [], highlightEnds: [],
        actionPages: [], actionIDs: [], actionKinds: [], actionLabels: [], actionPlacements: [], actionValues: [],
        sheetKind: "", sheetTitle: "", sheetBodyText: "", sheetPrompt: "", animationStart: nil
    )

    private static func append(_ activity: ContentActivity, index: Int, to s: inout ActivitiesPlayerScreen.State,
                               media: [String: MediaMapEntry], playback: Playback) {
        let document = activity.document
        switch document.renderable {
        case .canvas(let canvas):
            s.pageKinds.append("canvas")
            s.appendPage(background: document.background, media: media, verticalAnchor: canvas.verticalAnchor)
            for (object, raw) in zip(canvas.objects, rawObjects(document.raw)) { s.appendObject(object, raw: raw, page: index) }
        case .write(let write):
            s.pageKinds.append("write")
            s.appendPage(background: document.background, media: media, placeholder: write.placeholder ?? "")
            s.appendObject(write.prompt, raw: document.raw[path: ["content", "prompt"]] ?? .null, page: index)
        case .video(let video):
            s.pageKinds.append("video")
            s.appendPage(background: document.background, media: media)
            s.setVideo(video, entry: videoEntry(video, media: media), media: media,
                       playback: playback.videos[index], at: index)
        case .youtube:
            s.pageKinds.append("youtube")
            s.appendPage(background: document.background, media: media)
        case .fallback(let title, let body):
            s.pageKinds.append("fallback")
            s.appendPage(title: title, body: body, background: document.background, media: media)
        }
        for action in document.actions {
            s.actionPages.append(index)
            s.actionIDs.append(action.id)
            s.actionKinds.append(action.kind.rawValue)
            s.actionLabels.append(action.label)
            s.actionPlacements.append(action.placement.rawValue)
            s.actionValues.append(payloadString(action, "url"))
        }
    }

    private static func objects(canvas: CanvasContent, raw: JSONValue) -> [(TextObject, Bool)] {
        let raws = rawObjects(raw)
        return canvas.objects.enumerated().map { index, object in
            (object, raws.indices.contains(index) ? label(raws[index]) : false)
        }
    }

    private static func rawObjects(_ raw: JSONValue) -> [JSONValue] {
        if case .array(let items)? = raw[path: ["content", "objects"]] { return items }
        return []
    }

    private static func label(_ raw: JSONValue?) -> Bool {
        if case .string(let label)? = raw?[path: ["label"]] { return label != "none" }
        return false
    }

    private static func layoutWidth(_ object: TextObject) -> Double {
        object.transform.width > 0 ? object.transform.width : Layout.slotWidth
    }

    static func payloadString(_ action: ActivityAction, _ key: String) -> String {
        if case .string(let text)? = action.payload?[path: [.key(key)]] { return text }
        return ""
    }

    /// The face C-092 draws a font key in (D18), as a UIFont for measuring. Asking C-092 for a face
    /// first registers the bundled families.
    private static func uiFont(key: String, weight: String, size: Double) -> UIFont {
        _ = CanvasTextObject.Font.sans.face(weight: .regular, size: 1)
        let style: String
        switch weight {
        case "regular": style = "Regular"
        case "medium": style = "Medium"
        default: style = "Bold"
        }
        let size = CGFloat(size)
        switch key {
        case "display": return UIFont(name: "Poppins-\(style)", size: size) ?? .systemFont(ofSize: size)
        case "mono": return UIFont(name: "CourierPrime-\(style == "Medium" ? "Regular" : style)", size: size) ?? .systemFont(ofSize: size)
        case "serif":
            let wght: Double = style == "Regular" ? 400 : style == "Medium" ? 500 : 700
            let descriptor = UIFontDescriptor(fontAttributes: [
                .name: "SourceSerif4Variable-Roman",
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [0x7767_6874: wght]
            ])
            return UIFont(descriptor: descriptor, size: size)
        default: return UIFont(name: "Inter-\(style)", size: size) ?? .systemFont(ofSize: size)
        }
    }
}

// MARK: - Building the parallel arrays

private extension ActivitiesPlayerScreen.State {
    mutating func appendPage(title: String = "", body: String = "", background: ActivityBackground,
                             media: [String: MediaMapEntry], verticalAnchor: String = "center", placeholder: String = "") {
        pageColorHexes.append(background.color)
        pageGradients.append(ActivityThumbnail.canvasGradient(background.gradient))
        pageImageURLs.append(background.image.flatMap { media[$0.mediaId]?.url } ?? "")
        pageImageFocalXs.append(background.image?.focal?.x ?? 0.5)
        pageImageFocalYs.append(background.image?.focal?.y ?? 0.5)
        pageWashHexes.append(background.wash?.color ?? "")
        pageWashOpacities.append(background.wash?.opacity ?? 0)
        pageVerticalAnchors.append(verticalAnchor)
        pageTitles.append(title)
        pageBodies.append(body)
        pagePlaceholders.append(placeholder)
        pageCaptionLines.append([])
        pagePresenterNames.append("")
        pagePresenterImageURLs.append("")
        pagePresenterInitials.append("")
        pageReferences.append("")
        pageRemainingTimes.append("")
        pageProgresses.append(0)
        pagePlaying.append(false)
        pageBuffering.append(false)
    }

    /// C-135's row for the page just appended. §Contract: the presenter is the document's, else the
    /// video's uploader; there is no Follow button (C-135 draws none).
    mutating func setVideo(_ video: VideoContent, entry: MediaMapEntry?, media: [String: MediaMapEntry],
                           playback: ActivityViewerMapper.Playback.Video?, at index: Int) {
        let position = pageIndexes.count - 1
        let documentName = video.presenter?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = documentName.isEmpty ? entry?.uploaderName ?? "" : documentName
        pagePresenterNames[position] = name
        pagePresenterImageURLs[position] = video.presenter?.avatarMediaId.flatMap { media[$0]?.url } ?? ""
        pagePresenterInitials[position] = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        pageReferences[position] = video.presenter?.subtitle ?? ""
        let duration = (playback?.duration ?? 0) > 0 ? playback?.duration ?? 0 : entry?.durationSeconds ?? 0
        let elapsed = playback?.position ?? 0
        pageRemainingTimes[position] = duration > 0 ? Self.clock(max(0, duration - elapsed)) : ""
        pageProgresses[position] = duration > 0 ? min(1, max(0, elapsed / duration)) : 0
        pagePlaying[position] = playback?.playing ?? false
        pageBuffering[position] = playback?.buffering ?? false
    }

    /// One C-092 object, its marks and highlights (UTF-16 offsets, passed as stored — 02 §3).
    mutating func appendObject(_ object: TextObject, raw: JSONValue, page: Int) {
        let index = objectTexts.count
        func string(_ key: String, _ fallback: String) -> String {
            if case .string(let value)? = raw[path: [.key(key)]] { return value }
            return fallback
        }
        objectPages.append(page)
        objectTexts.append(object.text)
        objectFonts.append(ActivitiesEditorMapper.fontKey(object.font))
        objectColors.append(object.color)
        objectWeights.append(ActivitiesEditorMapper.weightName(object.weight))
        objectSizes.append(object.size)
        objectAlignments.append(object.alignment)
        objectLabels.append(string("label", "none"))
        objectListStyles.append(string("listStyle", "none"))
        if case .number(let start)? = raw[path: ["startNumber"]] { objectStartNumbers.append(Int(start)) } else { objectStartNumbers.append(1) }
        if case .string(let kind)? = raw[path: ["animation", "kind"]] { objectAnimations.append(kind) } else { objectAnimations.append("none") }
        objectAnimationLoops.append(raw[path: ["animation", "loop"]] == .bool(true))
        objectEffects.append(string("effect", "none"))
        objectXs.append(object.transform.x)
        objectYs.append(object.transform.y)
        objectScales.append(object.transform.scale)
        objectRotations.append(object.transform.rotation)
        objectWidths.append(object.transform.width)
        for mark in object.marks {
            markObjects.append(index)
            markStarts.append(mark.start)
            markEnds.append(mark.end)
            markKinds.append(mark.kind)
            markHrefs.append(mark.href ?? "")
        }
        for highlight in object.highlights {
            highlightObjects.append(index)
            highlightStarts.append(highlight.start)
            highlightEnds.append(highlight.end)
        }
    }

    /// C-135's remaining time, `m:ss`.
    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.up))
        return "\(total / 60):" + (total % 60 < 10 ? "0" : "") + "\(total % 60)"
    }
}
