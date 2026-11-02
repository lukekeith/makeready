import SwiftUI

struct InvitesHomeContainer: View {
    static let searchDebounce: Duration = .milliseconds(300)
    var onOpen: (InvitesHomeMapper.InvitationRowSelection) -> Void = { _ in }

    @Environment(AuthManager.self) private var authManager
    @State private var selection = InvitesHomeMapper.Selection()
    @State private var openMenu: InvitesHomeMapper.Dimension?
    @State private var searchActive = false
    @State private var searchTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?
    @State private var loading = true
    @State private var loadID: UUID?

    var body: some View {
        let app = AppState.shared
        let output = InvitesHomeMapper.output(
            window: app.invitationFeedWindow,
            entities: Dictionary(uniqueKeysWithValues: app.invitations.all.map { ($0.id, $0) }),
            filters: app.invitationFilters, selection: selection, now: Date(), timeZone: .current,
            loading: loading)
        InvitesHomeScreen(
            state: output.state,
            onSearch: { text in
                searchTask?.cancel()
                searchTask = Task { @MainActor in
                    do { try await Task.sleep(for: Self.searchDebounce) } catch { return } // Cancellation discards a superseded query.
                    guard !Task.isCancelled else { return }
                    selection.search = text
                }
            },
            onOpenFilter: { openMenu = InvitesHomeMapper.Dimension(rawValue: $0) },
            onOpenInvite: { row in if let target = output.selection(atRow: row) { onOpen(target) } },
            onOpenRequest: { row in if let target = output.selection(atRow: row) { onOpen(target) } },
            onSearchActiveChange: { searchActive = $0 }, showsNav: false, filtersLocally: false
        )
        .preference(key: UI2HidesTopNavKey.self, value: searchActive)
        .filterMenuPresentation(isPresented: openMenu != nil, onDismiss: { openMenu = nil }) {
            if let dimension = openMenu {
                let selected = InvitesHomeMapper.selectedID(dimension, selection) ?? InvitesHomeMapper.allID
                FilterMenuOverlay(options: InvitesHomeMapper.options(dimension, filters: app.invitationFilters),
                                  selectionMode: .single, selectedIDs: [selected],
                                  onClose: { openMenu = nil }, onSave: { ids in
                    selection = InvitesHomeMapper.saving(ids, in: dimension, selection: selection)
                    openMenu = nil
                    reload()
                })
            }
        }
        .task { reload() }
        .pageRefresh {
            reload()
            await loadTask?.value
        }
        .onDisappear { searchTask?.cancel(); loadTask?.cancel(); loadID = nil }
    }

    private var actions: InvitationActions {
        InvitationActions(onUnauthorized: { [authManager] in
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "InvitesHomeContainer.signOut", surface: false)
            }
        })
    }
    private func reload() {
        loadTask?.cancel()
        let query = selection.query
        let id = UUID()
        loadID = id
        loading = true
        loadTask = Task { @MainActor in
            _ = await actions.loadInvitationFeed(query)
            if loadID == id { loading = false; loadID = nil }
        }
    }
}
