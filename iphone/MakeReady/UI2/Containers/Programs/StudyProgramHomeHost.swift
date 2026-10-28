import SwiftUI

/// ui2-programs D1: the `.studyProgramHome` destination of the shell's stacks — the program page.
struct StudyProgramHomeHost: View {
    let id: String
    let name: String

    var body: some View {
        StudyProgramHomeContainer(programId: id, name: name)
    }
}
