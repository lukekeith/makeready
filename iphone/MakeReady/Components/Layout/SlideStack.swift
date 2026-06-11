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

    /// Which side of the primary pane the detail slides in from.
    /// `.trailing` (default) is the standard push-style slide. `.leading`
    /// preserves the inverted detail-on-the-left layout some pages use
    /// (e.g. GroupHomePage's settings screen) — the primary slides right
    /// and the detail enters from the left.
    enum DetailEdge {
        case trailing
        case leading
    }

    @Binding var item: Item?
    var animation: Animation = Motion.standard
    /// Edge-swipe-back is only supported for `.trailing` details; it is
    /// ignored when `detailEdge == .leading`.
    var edgeSwipeBack: Bool = false
    var detailEdge: DetailEdge = .trailing
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

    /// Whether edge-swipe-back is actually active (leading details don't
    /// support it — the gesture geometry assumes a trailing pane).
    private var swipeBackActive: Bool {
        edgeSwipeBack && detailEdge == .trailing
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // Trailing: [primary][detail], at rest offset 0, slid -width.
            // Leading:  [detail][primary], at rest offset -width, slid 0.
            let restOffset: CGFloat = detailEdge == .trailing ? 0 : -width
            let slidOffset: CGFloat = detailEdge == .trailing ? -width : 0

            HStack(spacing: 0) {
                if detailEdge == .leading {
                    detailPane(width: width)
                }

                primary()
                    .frame(width: width)

                if detailEdge == .trailing {
                    detailPane(width: width)
                }
            }
            .compositingGroup()
            .offset(x: (slid ? slidOffset : restOffset) + dragOffset + dismissDragCarry)
            .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .global)
                    .updating($dragOffset) { value, state, transaction in
                        // Edge-swipe-back: right-drag starting at the left
                        // edge while the detail pane is shown.
                        guard swipeBackActive,
                              slid,
                              value.startLocation.x < 40,
                              value.translation.width > 0 else { return }
                        transaction.animation = nil
                        state = value.translation.width
                    }
                    .onEnded { value in
                        guard swipeBackActive, slid, value.startLocation.x < 40 else { return }
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
                including: swipeBackActive ? .all : .subviews
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

    @ViewBuilder
    private func detailPane(width: CGFloat) -> some View {
        ZStack {
            if let mountedItem {
                detail(mountedItem)
                    .id(mountedItem)
            }
        }
        .frame(width: width)
    }
}

// MARK: - Bool-driven convenience

extension SlideStack where Item == Bool {
    /// Flag-driven variant for sliders whose detail pane has no identity —
    /// a single fixed second screen presented and dismissed by a Bool
    /// (e.g. EditReadActivityPage's theme editor). Same choreography as the
    /// item-driven form; the detail content mounts one runloop before the
    /// slide and stays mounted until the slide-out completes.
    init(
        isPresented: Binding<Bool>,
        animation: Animation = Motion.standard,
        edgeSwipeBack: Bool = false,
        detailEdge: DetailEdge = .trailing,
        onDismissComplete: (() -> Void)? = nil,
        @ViewBuilder primary: @escaping () -> Primary,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.init(
            item: Binding<Bool?>(
                get: { isPresented.wrappedValue ? true : nil },
                set: { isPresented.wrappedValue = ($0 != nil) }
            ),
            animation: animation,
            edgeSwipeBack: edgeSwipeBack,
            detailEdge: detailEdge,
            onDismissComplete: onDismissComplete,
            primary: primary,
            detail: { _ in detail() }
        )
    }
}
