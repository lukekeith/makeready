//
//  TabSlider.swift
//  MakeReady
//
//  Tab slider with animated background indicator
//

import SwiftUI

struct TabSlider: View {
    let tabs: [String]
    @Binding var selectedIndex: Int
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    // Don't wrap in withAnimation - matchedGeometryEffect handles its own animation
                    selectedIndex = index
                } label: {
                    Text(tab)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                if selectedIndex == index {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: "#6c47ff"))
                                        .matchedGeometryEffect(id: "tab_background", in: animation)
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        // Let matchedGeometryEffect use this single animation - prevents curve conflicts
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.2))
                .cornerRadius(4)
        )
    }
}

#Preview("TabSlider - All Variations") {
    @Previewable @State var selectedIndex1 = 0
    @Previewable @State var selectedIndex2 = 0
    @Previewable @State var selectedIndex3 = 0
    
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("3 Tabs")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                TabSlider(
                    tabs: ["Overview", "Studies", "Enrollments"],
                    selectedIndex: $selectedIndex1
                )
            }
            
            VStack(spacing: 8) {
                Text("2 Tabs")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                TabSlider(
                    tabs: ["Active", "Completed"],
                    selectedIndex: $selectedIndex2
                )
            }
            
            VStack(spacing: 8) {
                Text("4 Tabs")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                TabSlider(
                    tabs: ["All", "Groups", "Members", "Settings"],
                    selectedIndex: $selectedIndex3
                )
            }
        }
        .padding()
    }
}
