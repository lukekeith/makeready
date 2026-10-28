import Foundation

/// ui2-programs D10: one program setting the page opens an edit page for — the six editable rows
/// of study-program-home's settings card (D7: "Lessons" stays inert, D19: "Group leader" is
/// display-only).
enum ProgramField: String, Hashable, CaseIterable {
    case name, description, visibility, ageRange, maxMembers, directoryAccess

    /// StudyProgramHomeScreen's row label → its field; any other label is nil (the tap does nothing).
    init?(label: String) {
        switch label {
        case "Study name": self = .name
        case "Description": self = .description
        case "Visibility": self = .visibility
        case "Age": self = .ageRange
        case "Maximum members": self = .maxMembers
        case "Member directory access": self = .directoryAccess
        default: return nil
        }
    }
}
