//
//  FilterChipDropdown.swift
//  MakeReady
//
//  Two reusable views that compose the Library filter dropdowns:
//
//  1. `FilterChipDropdownTrigger` — the chip-styled button that goes into the
//     filter row. Tapping it asks the parent to expand a panel.
//  2. `FilterChipDropdownPanel` — the wrapped-chip overlay panel that the
//     parent positions just below the trigger row inside a ZStack.
//
//  The parent owns presentation (which dropdown is expanded, scrim, layout)
//  to keep these views context-free.
//

import SwiftUI

// MARK: - Trigger

/// Compact chip styled like the existing horizontal-scroll FilterPill, with a
/// small chevron-down. White background when `isActive` (the dropdown has any
/// selection), translucent otherwise.
struct FilterChipDropdownTrigger: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(Typography.s13Medium)
                    .foregroundColor(isActive ? Color.appBackground : .white.opacity(0.7))
                Image(systemName: "chevron.down")
                    .font(Typography.s10Semibold)
                    .foregroundColor(isActive ? Color.appBackground : .white.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isActive ? AnyShapeStyle(Color.white) : AnyShapeStyle(.ultraThinMaterial))
                    .environment(\.colorScheme, .dark)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Panel

/// Single item rendered in the wrapped chip layout inside a panel.
struct FilterChipDropdownItem: Identifiable, Hashable {
    let id: String
    let label: String
}

/// Overlay panel showing every available item as a wrapped chip. Selected
/// chips render white. Top bar contains an inline search input on the left
/// (tap anywhere in that area to focus) and an optional "Show all" button on
/// the right that clears the parent's selection. When the chip list overflows
/// the cap, the chip area scrolls vertically while the top bar stays pinned.
///
/// The parent is responsible for placing this view (typically as a `.overlay`
/// or in a ZStack) just below the trigger row, and for the tap-outside scrim
/// that dismisses it.
struct FilterChipDropdownPanel: View {
    let items: [FilterChipDropdownItem]
    let selectedIds: Set<String>
    /// When true, the "Show all" button is rendered (dimmed + disabled while
    /// nothing is selected). Set to false on single-select dropdowns where
    /// "clear" doesn't apply (e.g. media type / time).
    var showClearAll: Bool = true
    /// Message rendered in the chip area when there are no items to show.
    /// Set per-dropdown so the panel can explain *why* it's empty
    /// (e.g. "You are the only group leader in this org").
    var emptyMessage: String = "Nothing to show yet."
    let onToggle: (String) -> Void
    let onClearAll: () -> Void

    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    /// Cap on chip-area height. Keeps the panel from extending past the bottom
    /// nav on phones with many tags.
    private let chipsMaxHeight: CGFloat = 360

    private var filteredItems: [FilterChipDropdownItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar

            Divider()
                .background(Color.white.opacity(0.06))

            chipsArea
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        // Soft drop shadow to lift the panel off the dimmed page behind it.
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
    }

    /// Top bar with inline search on the left + optional "Show all" on the
    /// right. Tapping anywhere in the search area (icon, padding, blank space)
    /// focuses the field; the trailing button stays independently tappable.
    private var topBar: some View {
        HStack(spacing: 8) {
            searchField
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { isSearchFocused = true }

            if showClearAll {
                showAllButton
            }
        }
        .padding(.horizontal, 14)
        // Lock the bar's height so the TextField's focus-state size jitter
        // (cursor / edit-menu adornments) can't propagate up to the panel.
        .frame(height: 44)
    }

    /// Plain text field with a custom-styled placeholder rendered behind it.
    /// Avoids `TextField(prompt:)` so the placeholder color is fully under our
    /// control on the panel's dark background.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(Typography.s14)
                .foregroundColor(.white.opacity(0.4))

            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("Search")
                        .font(Typography.s14)
                        .foregroundColor(.white.opacity(0.4))
                        .allowsHitTesting(false)
                }
                TextField("", text: $searchText)
                    .font(Typography.s14)
                    .foregroundColor(.white)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var showAllButton: some View {
        Button(action: onClearAll) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .font(Typography.s14)
                    .foregroundColor(.white.opacity(0.5))
                Text("Show all")
                    .font(Typography.s14Semibold)
                    .foregroundColor(.white)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(selectedIds.isEmpty ? 0.4 : 1)
        .disabled(selectedIds.isEmpty)
    }

    @ViewBuilder
    private var chipsArea: some View {
        if filteredItems.isEmpty {
            Text(searchText.isEmpty ? emptyMessage : "No matches")
                .font(Typography.s13)
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        } else {
            // `.fixedSize(vertical: true)` forces the ScrollView to report its
            // ideal vertical size (= chipsFlow's natural height). `.frame(maxHeight:)`
            // caps that ideal at chipsMaxHeight. Net effect: the panel hugs
            // content for short lists, and caps at chipsMaxHeight with internal
            // scrolling for long ones.
            ScrollView {
                chipsFlow
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: chipsMaxHeight)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chipsFlow: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(filteredItems) { item in
                chip(for: item)
            }
        }
        .padding(14)
    }

    private func chip(for item: FilterChipDropdownItem) -> some View {
        let isSelected = selectedIds.contains(item.id)
        return Button {
            onToggle(item.id)
        } label: {
            Text(item.label)
                .font(Typography.s13Medium)
                .foregroundColor(isSelected ? Color.appBackground : .white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FilterChipDropdownPreview()
}

private struct FilterChipDropdownPreview: View {
    @State private var datasetIndex: Int = 1
    @State private var selectedIds: Set<String> = []

    private static let datasetLabels: [String] = ["1 item", "20 items", "500 items"]
    private static let datasetCounts: [Int] = [1, 20, 500]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            triggerRow
            panel
            Spacer()
        }
        .padding(16)
    }

    private var triggerRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<Self.datasetLabels.count, id: \.self) { i in
                trigger(at: i)
            }
        }
    }

    private func trigger(at index: Int) -> some View {
        FilterChipDropdownTrigger(
            label: Self.datasetLabels[index],
            isActive: datasetIndex == index,
            action: { selectDataset(index) }
        )
    }

    private func selectDataset(_ index: Int) {
        datasetIndex = index
        selectedIds = []
    }

    private var panel: some View {
        FilterChipDropdownPanel(
            items: items,
            selectedIds: selectedIds,
            onToggle: toggle,
            onClearAll: clearAll
        )
    }

    private var items: [FilterChipDropdownItem] {
        Self.sampleLabels(Self.datasetCounts[datasetIndex])
    }

    private func toggle(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func clearAll() {
        selectedIds.removeAll()
    }

    private static func sampleLabels(_ count: Int) -> [FilterChipDropdownItem] {
        let pool: [String] = [
            "Faith", "Leadership", "Youth", "Marriage", "Parenting", "Bible",
            "Discipleship", "Evangelism", "Worship", "Prayer", "Missions",
            "Outreach", "Family", "Kids", "Men", "Women", "Theology", "Grace",
            "Community", "Service", "Mercy", "Justice", "Hope", "Joy", "Peace",
        ]
        var result: [FilterChipDropdownItem] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let word: String = pool[i % pool.count]
            let item = FilterChipDropdownItem(id: "tag-\(i)", label: "\(word) \(i + 1)")
            result.append(item)
        }
        return result
    }
}
