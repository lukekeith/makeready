import SwiftUI

/// ui2-groups-browse D1: the `.groupDetail` destination of the shell's stacks — the group page.
struct GroupDetailHost: View {
    let id: String
    let name: String

    var body: some View {
        GroupDetailContainer(groupId: id, name: name)
    }
}
