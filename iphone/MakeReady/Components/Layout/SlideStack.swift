//
//  SlideStack.swift
//  MakeReady
//
//  Canonical horizontal slide navigation container (Phase 3.3).
//  Replaces the hand-rolled HStack + offset(x:) sliders that each page
//  reimplemented (with their own copies of the two-step insertion pattern,
//  asyncAfter unmount waits, and animation modifiers).
//
//  What it owns, so pages don't have to:
//  - Two-step insertion: detail content mounts one runloop before the
//    slide starts, so the pane animates in with its content fully present
//    (prevents the "content pops in at final position" failure class —
//    see SWIFTUI_TRANSITIONS.md).
//  - Single animation driver: explicit withAnimation per transition; no
//    implicit .animation modifier to fight with (and no curve mixing).
//  - Completion-tied unmount: detail content stays mounted until the
//    slide-out actually finishes (replaces asyncAfter(0.35) waits).
//  - .compositingGroup() before .offset so composite panes move as one
//    rendered layer.
//  - Optional edge-swipe-back (additive — off by default).
//
//  Usage:
//      SlideStack(item: $editingActivityId) {
//          dayContent
//      } detail: { activityId in
//          editPane(for: activityId)
//      }
//
//  `item` is the page's navigation state: non-nil presents the detail
//  pane, nil dismisses it. The detail builder receives the MOUNTED item,
//  which outlives the binding during slide-out — always build content
//  from it, never from page state that nils out on dismissal.
//

import SwiftUI

struct SlideStack<Item: Equatable & Hashable, Primary: View, Detail: View>: View {

    @Binding var item: Item?
    var animation: Animation = Motion.standard
    var edgeSwipeBack: Bool = false
    /// Runs after a dismissal's slide-out completes and the detail
    /// content has been unmounted.
    var onDismissComplete: (() -> Void)? = nil
    @ViewBuilder let primary: () -> Primary
    @ViewBuilder let detail: (Item) -> Detail

    /// The item whose content is mounted in the detail pane. Outlives
    /// `item` during slide-out so content doesn't vanish mid-animation.
    @State private var mountedItem: Item?

    /// Drives the offset. Flipped one runloop after mounting (insertion)
    /// and before unmounting (dismissal).
    @State private var slid = false

    /// Carries the final drag position into a swipe-back dismissal so the
    /// pane doesn't jump when @GestureState resets (same pattern as
    /// ManagedPageView).
    @State private var dismissDragCarry: CGFloat = 0

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            HStack(spacing: 0) {
                primary()
                    .frame(width: width)

                ZStack {
                    if let mountedItem {
                        detail(mountedItem)
                            .id(mountedItem)
                    }
                }
                .frame(width: width)
            }
            .compositingGroup()
            .offset(x: (slid ? -width : 0) + dragOffset + dismissDragCarry)
            .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .global)
                    .updating($dragOffset) { value, state, transaction in
                        // Edge-swipe-back: right-drag starting at the left
                        // edge while the detail pane is shown.
                        guard slid,
                              value.startLocation.x < 40,
                              value.translation.width > 0 else { return }
                        transaction.animation = nil
                        state = value.translation.width
                    }
                    .onEnded { value in
                        guard slid, value.startLocation.x < 40 else { return }
                        if value.translation.width > 80 {
                            // Transfer the drag position so the dismissal
                            // animates from where the finger left off.
                            dismissDragCarry = value.translation.width
                            item = nil
                        }
                    },
                // .subviews fully disables the container gesture when
                // swipe-back is off, so it can never compete with pane
                // content gestures (scrolling, card reorder).
                including: edgeSwipeBack ? .all : .subviews
            )
        }
        .onChange(of: item) { _, newItem in
            if let newItem {
                if mountedItem == nil {
                    // Two-step insertion: mount now (invisible — the pane is
                    // offscreen), slide on the next runloop so layout
                    // completes before the animation starts.
                    mountedItem = newItem
                    DispatchQueue.main.async {
                        // Re-check: a same-tick dismissal could have landed.
                        guard item != nil else { return }
                        withAnimation(animation) {
                            slid = true
                        }
                    }
                } else {
                    // Detail already mounted: swap content in place, and
                    // re-slide if a dismissal was in flight.
                    mountedItem = newItem
                    if !slid {
                        withAnimation(animation) {
                            slid = true
                        }
                    }
                }
            } else if slid {
                withAnimation(animation) {
                    slid = false
                } completion: {
                    // A re-presentation may have started mid-dismissal —
                    // only unmount if we're still dismissed.
                    guard item == nil else { return }
                    mountedItem = nil
                    dismissDragCarry = 0
                    onDismissComplete?()
                }
            } else {
                // Dismissed before the deferred slide ever started.
                mountedItem = nil
                dismissDragCarry = 0
            }
        }
    }
}
