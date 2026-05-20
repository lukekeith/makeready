//
//  SwipeableScrollView.swift
//  MakeReady
//
//  A ScrollView wrapper that automatically handles SwipeState coordination
//  for SwipeableCard components. Disables scrolling while cards are being swiped.
//
//  Usage:
//    SwipeableScrollView {
//        ForEach(items) { item in
//            SwipeableCard(...) { ... }
//        }
//    }
//

import SwiftUI

struct SwipeableScrollView<Content: View>: View {
    @StateObject private var swipeState = SwipeState()

    let axes: Axis.Set
    let showsIndicators: Bool
    let content: Content

    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content
                .environment(\.swipeState, swipeState)
        }
        .scrollDisabled(swipeState.isSwiping)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        SwipeableScrollView {
            VStack(spacing: 8) {
                ForEach(0..<5) { index in
                    SwipeableCard(
                        slideButtons: [
                            SlideButton(icon: "trash", style: .delete) {
                                print("Delete \(index)")
                            }
                        ],
                        onTap: {
                            print("Tapped \(index)")
                        }
                    ) {
                        HStack {
                            Text("Swipeable Item \(index + 1)")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
        }
    }
}
