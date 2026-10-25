import SwiftUI

/// SPEC D10: an unwired root — the layout background, nothing else.
struct EmptyPage: View {
    var body: some View { Token.layoutBackground.ignoresSafeArea() }
}
