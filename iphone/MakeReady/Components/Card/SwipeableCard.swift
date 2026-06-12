//
//  SwipeableCard.swift
//  MakeReady
//
//  Generic wrapper component that adds swipe-to-reveal action buttons to any card
//  Follows iOS native pattern (Mail, Messages, Reminders)
//
//  Uses CardGestureCoordinator for proper UIKit gesture handling with:
//  - Tap gesture
//  - Pan gesture (horizontal swipe)
//  - Proper ScrollView compatibility via velocity-based direction locking
//

import SwiftUI
import UIKit

struct SwipeableCard<Content: View>: View {
    let content: Content
    let slideButtons: [SlideButton]
    let isSwipeEnabled: Bool
    /// When true (default), the card content is rasterized via `.drawingGroup()`
    /// during swipe to keep child views from compositing independently. Disable
    /// this for cards whose content includes a `UIViewRepresentable` (UIKit
    /// views can't be flattened into a Metal texture, which produces
    /// "Unable to render flattened version" errors and a yellow placeholder).
    let rasterizesContent: Bool
    /// When false, the card's tap gesture is suppressed. Combined with
    /// `isSwipeEnabled: false` this also removes the gesture-coordinator
    /// overlay entirely so child UIViewRepresentables (e.g. UITextView)
    /// receive their own touches without being intercepted at the SwiftUI
    /// hit-test layer. Default true.
    let isTapEnabled: Bool

    let onTap: (() -> Void)?

    // MARK: - Environment

    @Environment(\.swipeState) private var swipeState

    // MARK: - State

    @State private var offset: CGFloat = 0
    @State private var isRevealed: Bool = false
    @State private var dragStartOffset: CGFloat = 0

    // Constants for button sizing and animation
    private let minButtonSize: CGFloat = 24
    private let maxButtonSize: CGFloat = 48
    private let minIconSize: CGFloat = 12
    private let maxIconSize: CGFloat = 20
    private let buttonSpacing: CGFloat = 8

    init(
        slideButtons: [SlideButton],
        isSwipeEnabled: Bool = true,
        rasterizesContent: Bool = true,
        isTapEnabled: Bool = true,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.slideButtons = slideButtons
        self.isSwipeEnabled = isSwipeEnabled
        self.rasterizesContent = rasterizesContent
        self.isTapEnabled = isTapEnabled
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Action buttons (revealed when swiped)
            // When revealed, buttons have higher zIndex to receive taps above the content's hit area
            if !slideButtons.isEmpty && isSwipeEnabled && abs(offset) > 5 {
                buttonRow
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .zIndex(isRevealed ? 2 : 0)
            }

            // Card content (slides left to reveal buttons)
            // drawingGroup() rasterizes the view hierarchy into a single Metal texture,
            // completely preventing child views from animating independently during swipe.
            // Skipped when content contains a UIViewRepresentable (Metal can't flatten UIKit views).
            Group {
                if rasterizesContent {
                    content.drawingGroup()
                } else {
                    content
                }
            }
                .offset(x: isSwipeEnabled ? offset : 0)
                .zIndex(1)  // Above buttons so card slides over them
                .overlay {
                    // Skip the gesture-coordinator UIView entirely when no
                    // gestures are wanted — its hit-testable surface would
                    // otherwise eat touches intended for child UIView­Representables
                    // (e.g. a UITextView accepting tap-and-hold for selection).
                    if isSwipeEnabled || isTapEnabled {
                        CardGestureCoordinator(
                            onTap: {
                                guard isTapEnabled else { return }
                                if isRevealed && isSwipeEnabled {
                                    closeButtons()
                                } else if !isRevealed {
                                    onTap?()
                                }
                            },
                            onSwipeChanged: { translationX, velocityX in
                                handleSwipeChanged(translationX: translationX, velocityX: velocityX)
                            },
                            onSwipeEnded: { translationX, velocityX in
                                handleSwipeEnded(translationX: translationX, velocityX: velocityX)
                            },
                            isSwipeEnabled: isSwipeEnabled,
                            swipeState: swipeState
                        )
                    }
                }
                .contentShape(Rectangle())
        }
    }

    // MARK: - Button Row

    private var buttonRow: some View {
        HStack(spacing: buttonSpacing) {
            ForEach(slideButtons) { button in
                let buttonSize = calculateButtonSize()
                let iconSize = calculateIconSize()
                let buttonOpacity = calculateOpacity()

                Button(action: {
                    print("SwipeableCard button tapped: \(button.icon)")
                    button.action()
                    closeButtons()
                }) {
                    Image(systemName: button.icon)
                        .font(.system(size: iconSize, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: iconSize, height: iconSize)
                }
                .frame(width: buttonSize, height: buttonSize)
                .background(buttonBackground(for: button.style))
                .cornerRadius(buttonSize / 2)
                .opacity(buttonOpacity)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
    }

    // MARK: - Swipe Gesture Handling

    private func handleSwipeChanged(translationX: CGFloat, velocityX: CGFloat) {
        let newOffset = dragStartOffset + translationX

        // Only allow swiping left (negative offset) to reveal buttons
        // Or swiping right when buttons are already revealed (to close)
        if newOffset < 0 {
            offset = newOffset
        } else if isRevealed {
            // Allow swipe right to close when revealed
            offset = min(newOffset, 0)
        }
    }

    private func handleSwipeEnded(translationX: CGFloat, velocityX: CGFloat) {
        let threshold = totalButtonWidth * 0.5

        withAnimation(Motion.springSnappy) {
            // Fast swipe left or past threshold = reveal
            if velocityX < -100 || abs(offset) > threshold {
                offset = revealedOffset
                isRevealed = true
            } else {
                // Close buttons
                closeButtons()
            }
        }

        // Update drag start offset for next gesture
        dragStartOffset = offset
    }

    // MARK: - Button Styling

    private func buttonBackground(for style: SlideButtonStyle) -> Color {
        switch style {
        case .reschedule:
            return Color.accentBlue  // Blue (Figma spec)
        case .delete:
            return Color.destructive  // Red (Figma spec)
        case .skip, .edit:
            return Color.white.opacity(0.2)  // White 20% (Figma spec)
        }
    }

    // MARK: - Progressive Reveal Calculations

    private var totalButtonWidth: CGFloat {
        let buttonCount = CGFloat(slideButtons.count)
        return (maxButtonSize * buttonCount) + (buttonSpacing * (buttonCount - 1)) + 8 + 16  // +8 for leading padding (gap), +16 for trailing padding
    }

    private var revealedOffset: CGFloat {
        return -totalButtonWidth
    }

    private var progress: CGFloat {
        guard totalButtonWidth > 0 else { return 0 }
        return min(abs(offset) / totalButtonWidth, 1.0)
    }

    private func calculateButtonSize() -> CGFloat {
        return minButtonSize + ((maxButtonSize - minButtonSize) * progress)
    }

    private func calculateIconSize() -> CGFloat {
        return minIconSize + ((maxIconSize - minIconSize) * progress)
    }

    private func calculateOpacity() -> Double {
        return Double(progress)
    }

    private func closeButtons() {
        withAnimation(Motion.springSnappy) {
            offset = 0
            isRevealed = false
            dragStartOffset = 0
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // Example with Event card
            SwipeableCard(
                slideButtons: [
                    SlideButton(icon: "trash", style: .delete) {
                        print("Delete tapped")
                    },
                    SlideButton(icon: "calendar", style: .reschedule) {
                        print("Reschedule tapped")
                    },
                    SlideButton(icon: "forward", style: .skip) {
                        print("Skip tapped")
                    },
                    SlideButton(icon: "pencil", style: .edit) {
                        print("Edit tapped")
                    }
                ],
                onTap: {
                    print("Card tapped!")
                }
            ) {
                CardEvent(
                    data: CardEventData(
                        id: "1",
                        title: "Community Gathering",
                        subtitle: "Main Campus",
                        imageStyle: .dateDisplay(day: 15, month: "JAN"),
                        metadata: [
                            DataItem(icon: "clock", value: "7:00 PM"),
                            DataItem(icon: "mappin", value: "Auditorium")
                        ],
                        status: .confirmed,
                        onTap: { print("Event tapped") }
                    )
                )
            }

            Spacer()
        }
        .padding(16)
    }
}
