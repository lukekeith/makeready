import SwiftUI

/// ui2-members-browse D1: the `.memberDetail` destination of the shell's stacks — the member page.
struct MemberDetailHost: View {
    let id: String
    let name: String

    var body: some View {
        MemberProfileContainer(memberId: id, name: name)
    }
}
