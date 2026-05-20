//
//  SearchableList.swift
//  MakeReady
//
//  Generic searchable list wrapper that replicates InviteContactsPage search experience
//  Works with any content type via ViewBuilder (similar to SwipeableGroupCard pattern)
//

import SwiftUI

/// Searchable list wrapper with animated search, optional alphabet scrubber, and filter section
struct SearchableList<Item: Identifiable & Hashable, Content: View, Filters: View, Header: View>: View {
    // MARK: - Data
    let items: [Item]
    let filterPredicate: (Item, String) -> Bool

    // MARK: - Content Builders
    @ViewBuilder let content: (Item) -> Content
    @ViewBuilder let filters: () -> Filters
    @ViewBuilder let header: () -> Header

    // MARK: - Configuration
    let placeholder: String
    let showAlphabetScrubber: Bool
    let sectionKeyPath: KeyPath<Item, String>?
    let emptyStateView: AnyView?
    let autoFocusSearch: Bool

    // MARK: - State
    @State private var searchText = ""
    @State private var internalSearchActive = false
    @FocusState private var searchFieldFocused: Bool
    @StateObject private var swipeState = SwipeState()
    
    // Optional external binding for search active state
    private var externalSearchActive: Binding<Bool>?
    
    private var isSearchActiveBinding: Binding<Bool> {
        Binding(
            get: { externalSearchActive?.wrappedValue ?? internalSearchActive },
            set: { newValue in
                if let binding = externalSearchActive {
                    binding.wrappedValue = newValue
                } else {
                    internalSearchActive = newValue
                }
            }
        )
    }
    
    private var isSearchActive: Bool {
        isSearchActiveBinding.wrappedValue
    }
    
    private var hasHeader: Bool {
        Header.self != EmptyView.self
    }
    
    private var shouldShowSearch: Bool {
        // Always show search if user has started searching
        if !searchText.isEmpty || isSearchActive {
            return true
        }
        
        // Simple item count logic:
        // - Lists with ≤10 items: no search needed
        // - Lists with >10 items: always show search
        return items.count > 10
    }
    
    // MARK: - Initializers

    /// Full initializer with auto-sectioning, filters, and header
    init(
        items: [Item],
        filterPredicate: @escaping (Item, String) -> Bool,
        placeholder: String = "Search",
        showAlphabetScrubber: Bool = false,
        sectionKeyPath: KeyPath<Item, String>? = nil,
        emptyStateView: AnyView? = nil,
        isSearchActive: Binding<Bool>? = nil,
        autoFocusSearch: Bool = true,
        @ViewBuilder content: @escaping (Item) -> Content,
        @ViewBuilder filters: @escaping () -> Filters,
        @ViewBuilder header: @escaping () -> Header
    ) {
        self.items = items
        self.filterPredicate = filterPredicate
        self.placeholder = placeholder
        self.showAlphabetScrubber = showAlphabetScrubber
        self.sectionKeyPath = sectionKeyPath
        self.emptyStateView = emptyStateView
        self.externalSearchActive = isSearchActive
        self.autoFocusSearch = autoFocusSearch
        self.content = content
        self.filters = filters
        self.header = header
    }

    // MARK: - Filtered Data

    private var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { filterPredicate($0, searchText) }
    }

    private var sectionedItems: [(String, [Item])] {
        guard let keyPath = sectionKeyPath else {
            // No sectioning - return all items under empty section
            return [("", filteredItems)]
        }

        // Group by first letter
        let grouped = Dictionary(grouping: filteredItems) { item in
            String(item[keyPath: keyPath].prefix(1).uppercased())
        }

        return grouped.map { (letter, items) in
            (letter, items.sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] })
        }.sorted { $0.0 < $1.0 }
    }

    // MARK: - Body

    var body: some View {
        contentWrapper
            // NOTE: Removed clipShape(cornerRadius: 32) - it was clipping the header's
            // close button in the top-left corner, making it untappable.
            .onChange(of: isSearchActive) { _, newValue in
                if newValue && autoFocusSearch {
                    searchFieldFocused = true
                } else {
                    searchFieldFocused = false
                    searchText = ""
                }
            }
    }
    
    // MARK: - Content Wrapper (Layered layout with gradient fade)

    private var contentWrapper: some View {
        ZStack(alignment: .top) {
            // Background: List content with fixed top padding and gradient mask
            VStack(spacing: 0) {
                // Content list with gradient mask
                if filteredItems.isEmpty {
                    // Empty state
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: listTopPadding)

                        if let emptyView = emptyStateView {
                            emptyView
                        } else {
                            defaultEmptyState
                        }
                    }
                } else {
                    // List with gradient mask at top
                    listContentWithPadding
                        .mask(
                            VStack(spacing: 0) {
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: gradientHeight)

                                Color.black
                            }
                        )
                }

                // Filters section - slides in from bottom
                if isSearchActive && !isFiltersEmpty {
                    filtersSection
                        .transition(.move(edge: .bottom))
                }
            }

            // Foreground: Header + Search field (moves up when searching)
            VStack(spacing: 0) {
                // Header
                if hasHeader {
                    header()
                        .opacity(isSearchActive ? 0 : 1)
                        .allowsHitTesting(!isSearchActive)
                }

                // Search field - only show if needed
                if shouldShowSearch {
                    SearchField(
                        isActive: isSearchActiveBinding,
                        searchText: $searchText,
                        isFocused: $searchFieldFocused,
                        placeholder: placeholder,
                        onClose: {
                            searchText = ""
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, hasHeader ? 8 : 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .offset(y: isSearchActive && hasHeader ? -headerHeight + 8 : 0)
        }
        .clipped()
        .animation(.easeInOut(duration: 0.5), value: isSearchActive)
    }
    
    // MARK: - Computed Properties
    
    private var headerHeight: CGFloat {
        // Height of the header
        return hasHeader ? 56 : 0
    }
    
    private var searchFieldHeight: CGFloat {
        // Height of search field with padding
        let topPadding: CGFloat = 16
        let bottomPadding: CGFloat = 16
        let fieldHeight: CGFloat = 48
        return topPadding + fieldHeight + bottomPadding
    }
    
    private var headerAndSearchHeight: CGFloat {
        // Total height of header + search field
        return headerHeight + searchFieldHeight
    }

    private var gradientHeight: CGFloat {
        // When searching with header hidden, just search field overlay
        if isSearchActive && hasHeader {
            return 52
        }
        // When header is present, gradient covers header + search area
        if hasHeader {
            return listTopPadding + 20
        }
        // No header — matches the standard 52pt pattern
        return 52
    }
    
    private var listTopPadding: CGFloat {
        // If search is hidden, use minimal padding
        if !shouldShowSearch {
            return hasHeader ? 56 + 16 : 16  // Header height + small gap, or just small gap
        }
        
        // Dynamic padding - reduces when searching to follow header movement
        if isSearchActive && hasHeader {
            return 60  // Reduced padding when searching
        } else {
            return 120 // Full padding when not searching
        }
    }

    // MARK: - List Content
    
    private var listContentWithPadding: some View {
        Group {
            if showAlphabetScrubber && sectionKeyPath != nil {
                // Use native UITableView with section index
                SectionedTableView(
                    sections: sectionedItems,
                    sectionIndexTitles: sectionedItems.map { $0.0 },
                    topInset: listTopPadding, // Dynamic padding
                    swipeState: swipeState,
                    onScroll: nil,
                    onFirstCellHeightMeasured: nil,
                    onSectionHeaderHeightMeasured: nil,
                    content: { item in
                        content(item)
                            .environment(\.swipeState, swipeState)
                    }
                )
            } else {
                // Use SwiftUI ScrollView for non-sectioned lists
                ScrollView {
                    VStack(spacing: 0) {
                        // Dynamic top padding - animates when searching
                        // Note: Animation handled by parent container
                        Color.clear
                            .frame(height: listTopPadding)

                        if sectionKeyPath != nil {
                            // Sectioned list with headers (no scrubber)
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                                ForEach(Array(sectionedItems.enumerated()), id: \.offset) { sectionIndex, section in
                                    let (letter, items) = section
                                    Section {
                                        ForEach(items) { item in
                                            content(item)
                                        }
                                    } header: {
                                        if !letter.isEmpty {
                                            Text(letter)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white50)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.appBackground)
                                        }
                                    }
                                    .id(letter)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 16)
                        } else {
                            // Non-sectioned list
                            LazyVStack(spacing: 4) {
                                ForEach(filteredItems) { item in
                                    content(item)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 16)
                        }
                    }
                    .environment(\.swipeState, swipeState)
                }
                .scrollDisabled(swipeState.isSwiping)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(spacing: 16) {
            filters()
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(Color.appBackground)
    }

    private var isFiltersEmpty: Bool {
        // Check if Filters is EmptyView
        return Filters.self == EmptyView.self
    }

    // MARK: - Default Empty State

    private var defaultEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white50)

            VStack(spacing: 8) {
                Text("No results")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Try a different search term")
                    .font(.system(size: 15))
                    .foregroundColor(.white50)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .opacity(0.2)  // 20% opacity
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill available space
        .padding(.vertical, 0)
    }
}

// MARK: - Convenience Initializers

extension SearchableList where Filters == EmptyView, Header == EmptyView {
    /// Initializer without filters section or header
    init(
        items: [Item],
        filterPredicate: @escaping (Item, String) -> Bool,
        placeholder: String = "Search",
        showAlphabetScrubber: Bool = false,
        sectionKeyPath: KeyPath<Item, String>? = nil,
        emptyStateView: AnyView? = nil,
        isSearchActive: Binding<Bool>? = nil,
        autoFocusSearch: Bool = true,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.filterPredicate = filterPredicate
        self.placeholder = placeholder
        self.showAlphabetScrubber = showAlphabetScrubber
        self.sectionKeyPath = sectionKeyPath
        self.emptyStateView = emptyStateView
        self.externalSearchActive = isSearchActive
        self.autoFocusSearch = autoFocusSearch
        self.content = content
        self.filters = { EmptyView() }
        self.header = { EmptyView() }
    }
}

extension SearchableList where Header == EmptyView {
    /// Initializer with filters but no header
    init(
        items: [Item],
        filterPredicate: @escaping (Item, String) -> Bool,
        placeholder: String = "Search",
        showAlphabetScrubber: Bool = false,
        sectionKeyPath: KeyPath<Item, String>? = nil,
        emptyStateView: AnyView? = nil,
        isSearchActive: Binding<Bool>? = nil,
        autoFocusSearch: Bool = true,
        @ViewBuilder content: @escaping (Item) -> Content,
        @ViewBuilder filters: @escaping () -> Filters
    ) {
        self.items = items
        self.filterPredicate = filterPredicate
        self.placeholder = placeholder
        self.showAlphabetScrubber = showAlphabetScrubber
        self.sectionKeyPath = sectionKeyPath
        self.emptyStateView = emptyStateView
        self.externalSearchActive = isSearchActive
        self.autoFocusSearch = autoFocusSearch
        self.content = content
        self.filters = filters
        self.header = { EmptyView() }
    }
}

extension SearchableList where Filters == EmptyView {
    /// Initializer with header but no filters
    init(
        items: [Item],
        filterPredicate: @escaping (Item, String) -> Bool,
        placeholder: String = "Search",
        showAlphabetScrubber: Bool = false,
        sectionKeyPath: KeyPath<Item, String>? = nil,
        emptyStateView: AnyView? = nil,
        isSearchActive: Binding<Bool>? = nil,
        autoFocusSearch: Bool = true,
        @ViewBuilder content: @escaping (Item) -> Content,
        @ViewBuilder header: @escaping () -> Header
    ) {
        self.items = items
        self.filterPredicate = filterPredicate
        self.placeholder = placeholder
        self.showAlphabetScrubber = showAlphabetScrubber
        self.sectionKeyPath = sectionKeyPath
        self.emptyStateView = emptyStateView
        self.externalSearchActive = isSearchActive
        self.autoFocusSearch = autoFocusSearch
        self.content = content
        self.filters = { EmptyView() }
        self.header = header
    }
}

// MARK: - Preview

// Sample Contact type for preview
private struct PreviewContact: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let hasPhone: Bool
}

#Preview {
    let sampleContacts = [
        PreviewContact(name: "Alice Anderson", hasPhone: true),
        PreviewContact(name: "Bob Brown", hasPhone: false),
        PreviewContact(name: "Charlie Chen", hasPhone: true),
        PreviewContact(name: "Diana Davis", hasPhone: true),
        PreviewContact(name: "Eve Evans", hasPhone: false),
        PreviewContact(name: "Frank Foster", hasPhone: true),
        PreviewContact(name: "Grace Garcia", hasPhone: true),
        PreviewContact(name: "Henry Harris", hasPhone: false),
        PreviewContact(name: "Luke Keith", hasPhone: true),
        PreviewContact(name: "Somebody Else", hasPhone: false),
        PreviewContact(name: "Pamela Keith", hasPhone: false),
    ]

    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        SearchableListPreview(contacts: sampleContacts)
    }
}

// Preview wrapper with state
private struct SearchableListPreview: View {
    let contacts: [PreviewContact]

    var body: some View {
        SearchableList(
            items: contacts,
            filterPredicate: { (contact: PreviewContact, query: String) in
                contact.name.lowercased().contains(query.lowercased())
            },
            placeholder: "Search contacts",
            showAlphabetScrubber: true,   // Enable alphabet scrubber on the right
            sectionKeyPath: \.name,       // Enable sectioning to show letter headers
            autoFocusSearch: false        // Disable auto-focus for preview (prevents keyboard from appearing)
        ) { (contact: PreviewContact) in
            // Row content
            HStack(spacing: 8) {
                Text(contact.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if contact.hasPhone {
                    Text("Invite")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.brandPrimary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        } header: {
            // Header with close icon on left and Next link on right
            PageTitle.iconLink(
                leftIcon: "xmark",
                rightLink: "Next",
                onLeftIconTap: {
                    print("Close tapped")
                },
                onRightLinkTap: {
                    print("Next tapped")
                }
            )
        }
    }
}
