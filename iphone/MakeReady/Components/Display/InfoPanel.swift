//
//  InfoPanel.swift
//  MakeReady
//
//  Reusable info panel component with two display modes:
//  - keyValue: Horizontal rows with label left, value right (e.g., "Joined  Jul 1, 2025")
//  - data: Stacked rows with label above value (e.g., "Phone\n213.862.3686")
//
//  Figma: Key-Value node 1721:25992, Data node 1721:26008
//

import SwiftUI

// MARK: - Data Structures

/// A single row of data in an InfoPanel
struct InfoPanelItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var onTap: (() -> Void)? = nil
}

/// Display mode for InfoPanel rows
enum InfoPanelMode {
    /// Label left, value right on same row (16px padding)
    case keyValue
    /// Label above value, stacked vertically (24px padding)
    case data
}

// MARK: - InfoPanel Component

struct InfoPanel: View {
    let items: [InfoPanelItem]
    let mode: InfoPanelMode

    init(items: [InfoPanelItem], mode: InfoPanelMode = .keyValue) {
        self.items = items
        self.mode = mode
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                // Row content
                switch mode {
                case .keyValue:
                    keyValueRow(item: item)
                case .data:
                    dataRow(item: item)
                }

                // Divider between rows (not after last)
                if index < items.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Row Variants

    private func keyValueRow(item: InfoPanelItem) -> some View {
        HStack(spacing: 16) {
            Text(item.label)
                .font(Typography.s14Semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.value)
                .font(Typography.s14Semibold)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
    }

    @ViewBuilder
    private func dataRow(item: InfoPanelItem) -> some View {
        if let onTap = item.onTap {
            Button(action: onTap) {
                dataRowContent(item: item)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            dataRowContent(item: item)
        }
    }

    private func dataRowContent(item: InfoPanelItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.label)
                .font(Typography.s14Semibold)
                .foregroundColor(.white)

            Text(item.value)
                .font(Typography.s14Semibold)
                .foregroundColor(item.onTap != nil ? Color.brandPrimary : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

// MARK: - Previews

#Preview("Key-Value Mode") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        InfoPanel(
            items: [
                InfoPanelItem(label: "Joined", value: "Jul 1, 2023"),
                InfoPanelItem(label: "Age", value: "23"),
                InfoPanelItem(label: "Completed activities", value: "18"),
                InfoPanelItem(label: "Last active", value: "Yesterday")
            ],
            mode: .keyValue
        )
        .padding(16)
    }
}

#Preview("Data Mode") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        InfoPanel(
            items: [
                InfoPanelItem(label: "Phone", value: "123.456.7890"),
                InfoPanelItem(label: "Email", value: "tony@starkindustries.com")
            ],
            mode: .data
        )
        .padding(16)
    }
}

#Preview("Both Modes") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 16) {
            InfoPanel(
                items: [
                    InfoPanelItem(label: "Joined", value: "Jul 1, 2023"),
                    InfoPanelItem(label: "Age", value: "23"),
                    InfoPanelItem(label: "Completed activities", value: "18"),
                    InfoPanelItem(label: "Last active", value: "Yesterday")
                ],
                mode: .keyValue
            )

            InfoPanel(
                items: [
                    InfoPanelItem(label: "Phone", value: "213.862.3686"),
                    InfoPanelItem(label: "Email", value: "luke@lukekeith.com")
                ],
                mode: .data
            )
        }
        .padding(16)
    }
}
