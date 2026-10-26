import SwiftUI

/// ui2-members-browse D1: the `.memberDetail` destination of the shell's stacks — a pushed page
/// (it owns its own scroll; the system bar is hidden, so it draws C-040, back = pop).
/// Task 16 of the plan points this body at `MemberProfileContainer`; until then it is the page's
/// header with the list-known name (members-profile §3 `loading`: "header renders with the name").
struct MemberDetailHost: View {
    let id: String
    let name: String
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: name,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground.ignoresSafeArea())
    }
}
