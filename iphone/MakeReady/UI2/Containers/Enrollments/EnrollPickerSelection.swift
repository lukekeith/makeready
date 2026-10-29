import Foundation

/// ui2-enrollment-create (final review I-1): how the group and program pickers keep the d2m
/// screen's pick honest without dropping the keyboard. The screens seed their query and selected
/// row once, at init, so the container re-keys them when the rows change underneath — but only on
/// what typing cannot change (the unfiltered source rows and the filter chips), never on the
/// query: a re-key rebuilds C-034 SearchField and loses its focus. Between re-keys the screen's
/// index can name a row that moved, so Select resolves through the tracked pick.
enum EnrollPickerSelection {
    /// What a picker screen is re-keyed on: a load (source ids) or a filter-chip Save.
    struct ScreenKey: Hashable {
        var sourceIds: [String]
        var filters: [Set<String>]
    }

    /// The id Select commits: the tracked pick while it is still listed, else the row at `index`.
    static func committedId(index: Int, rowIds: [String], trackedId: String?) -> String? {
        if let trackedId, rowIds.contains(trackedId) { return trackedId }
        return rowIds.indices.contains(index) ? rowIds[index] : nil
    }
}

extension InviteSelectGroupMapper {
    static func screenKey(_ input: Input) -> EnrollPickerSelection.ScreenKey {
        .init(sourceIds: input.groups.map(\.id), filters: [input.leaderIds, input.pickedOrgIds])
    }
}

extension EnrollSelectProgramMapper {
    static func screenKey(_ input: Input) -> EnrollPickerSelection.ScreenKey {
        .init(sourceIds: input.programs.map(\.id), filters: [input.leaderIds])
    }
}
