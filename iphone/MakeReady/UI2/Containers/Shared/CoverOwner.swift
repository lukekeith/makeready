import UIKit

/// ui2-programs D11: whose 16:9 cover the Edit cover page frames — a group's (group-cover-image)
/// or a program's. Supplies the stored cover fields, the save call and the page's own route.
enum CoverOwner: Hashable {
    case group(String)
    case program(String)

    /// The three stored cover fields.
    struct Fields: Equatable {
        var coverImageUrl: String?
        var coverOriginalUrl: String?
        var coverFraming: ImageFraming?
    }

    /// The owner's stored cover, or nil while it is not in AppState.
    @MainActor
    var fields: Fields? {
        switch self {
        case .group(let id):
            return AppState.shared.groups[id].map { Fields(coverImageUrl: $0.coverImageUrl, coverOriginalUrl: $0.coverOriginalUrl,
                                                           coverFraming: $0.coverFraming) }
        case .program(let id):
            return AppState.shared.programs[id].map { Fields(coverImageUrl: $0.coverImageUrl, coverOriginalUrl: $0.coverOriginalUrl,
                                                             coverFraming: $0.coverFraming) }
        }
    }

    /// The Edit cover page's route for this owner.
    func destination(_ source: ImageEditSource) -> UI2Destination {
        switch self {
        case .group(let id): return .editGroupCover(groupId: id, source: source)
        case .program(let id): return .editProgramCover(programId: id, source: source)
        }
    }

    /// Uploads the rendered cover (+ the original on a new pick); returns the new cover URL.
    @MainActor
    func save(rendered: UIImage, framing: ImageFraming, original: UIImage?) async throws -> String {
        switch self {
        case .group(let id):
            return try await GroupActions().saveCover(groupId: id, rendered: rendered, framing: framing, original: original).coverImageUrl
        case .program(let id):
            return try await ProgramActions().saveCover(programId: id, rendered: rendered, framing: framing, original: original).coverImageUrl
        }
    }

    /// group-cover-image D1/D2/F7 for any owner: inert until loaded, the picker with no cover,
    /// else the Edit · Change · View menu.
    static func coverTap(_ fields: Fields?) -> GroupDetailContainer.CoverTap {
        guard let fields else { return .none }
        return (fields.coverImageUrl ?? "").isEmpty ? .picker : .menu
    }

    /// group-cover-image D8 for any owner: the viewer shows the original, else the cover.
    static func viewerURL(_ fields: Fields) -> String? {
        if let original = fields.coverOriginalUrl, !original.isEmpty { return original }
        if let cover = fields.coverImageUrl, !cover.isEmpty { return cover }
        return nil
    }
}
