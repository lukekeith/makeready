//
//  PageHeader.swift
//  MakeReady
//
//  Page header with tabs
//

import SwiftUI

// MARK: - Tab Frame Preference Key

struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct PageHeader<TrailingContent: View>: View {
    let tabs: [String]
    @Binding var activeTab: Int
    let trailingContent: TrailingContent

    @State private var tabFrames: [Int: CGRect] = [:]

    init(
        tabs: [String],
        activeTab: Binding<Int>,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.tabs = tabs
        self._activeTab = activeTab
        self.trailingContent = trailingContent()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Tabs on the left - hug content
            HStack(spacing: 16) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    TabButton(
                        title: tab,
                        isActive: index == activeTab,
                        index: index,
                        onTap: {
                            withAnimation(Motion.standard) {
                                activeTab = index
                            }
                        }
                    )
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .coordinateSpace(name: "tabContainer")
            .overlayPreferenceValue(TabFramePreferenceKey.self) { frames in
                GeometryReader { geometry in
                    if let activeFrame = frames[activeTab] {
                        Rectangle()
                            .fill(Color(hex: "#6c47ff"))
                            .frame(width: activeFrame.width, height: 2)
                            .position(
                                x: activeFrame.midX,
                                y: geometry.size.height - 1
                            )
                            .animation(Motion.standard, value: activeTab)
                    }
                }
            }

            Spacer()

            trailingContent
        }
        .padding(16)
    }
}

extension PageHeader where TrailingContent == EmptyView {
    init(tabs: [String], activeTab: Binding<Int>) {
        self.init(tabs: tabs, activeTab: activeTab) { EmptyView() }
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(isActive ? .white : .white.opacity(0.7))
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: TabFramePreferenceKey.self,
                                value: [index: geometry.frame(in: .named("tabContainer"))]
                            )
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            PageHeader(
                tabs: ["Home"],
                activeTab: .constant(0)
            )
            Spacer()
        }
    }
}
