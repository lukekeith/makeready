import SwiftUI

/// ui2-programs D11: the `.editProgramCover` destination — the group cover's Edit cover page over
/// the program's cover (16:9, the same render and save shape).
struct EditProgramCoverContainer: View {
    let programId: String
    let source: ImageEditSource

    var body: some View {
        EditGroupCoverContainer(owner: .program(programId), source: source)
    }
}
