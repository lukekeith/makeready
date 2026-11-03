import SwiftUI

/// library-home §6: the Home tab's Library section root — a static placeholder (§3 `default`),
/// so there is nothing to read from `AppState` and no callback to map.
struct LibraryHomeContainer: View {
    var body: some View {
        LibraryHomeScreen(state: .comingSoon)
    }
}
