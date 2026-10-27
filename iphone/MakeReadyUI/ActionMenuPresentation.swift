import SwiftUI

// action-menu-overlay: C-066's presentation chrome (OQ-C-066-1, settled by the owner's Add-menu
// frame 4717:52460, 2026-10-26) — a full-screen dim with the menu slid up from the bottom edge,
// inset 4pt from the left, right and bottom. Tapping the dim or dragging the menu down dismisses.
// Under a `.ui2OverlayHost()` it draws above every piece of the shell's chrome, like C-036.

extension View {
    /// Presents `menu` (a C-066 ActionMenuOverlay) as the full-screen action sheet. `onHidden` runs
    /// once its slide-out has finished and the layer is unmounted — the moment a follow-up overlay
    /// can be presented (group-cover-image D8: the host keeps only the first presented overlay).
    func actionMenuPresentation<Menu: View>(
        isPresented: Bool,
        onDismiss: @escaping () -> Void,
        onHidden: @escaping () -> Void = {},
        @ViewBuilder menu: () -> Menu
    ) -> some View {
        modifier(HostableActionMenuPresentation(isPresented: isPresented, onDismiss: onDismiss, onHidden: onHidden, menu: menu()))
    }
}

enum ActionMenuMotion {
    // GAP — OQ-C-066-1: no motion token for the sheet's slide; a critically damped spring at the
    // menu-fade duration family's scale. Filed with the C-066 update (action-menu-overlay B6).
    static let slide = Animation.spring(duration: 0.35, bounce: 0)
    // GAP — frame 4717:52460: the menu sits 4pt from the left, right and bottom screen edges; no
    // spacing token names that role.
    static let edgeInset: CGFloat = 4
    // GAP — no dismiss threshold in the design: a drag past 80pt, or a flick projected past 160pt.
    static let dismissDistance: CGFloat = 80
    static let dismissProjection: CGFloat = 160

    /// Whether a released downward drag dismisses the menu.
    static func shouldDismiss(translation: CGFloat, predicted: CGFloat) -> Bool {
        translation > dismissDistance || predicted > dismissProjection
    }

    /// The menu's drag offset: follows the finger down, resists upward pulls (a quarter, 16pt max).
    static func dragOffset(_ translation: CGFloat) -> CGFloat {
        translation >= 0 ? translation : max(-16, translation / 4)
    }

}

/// The presented layer: the dim, then the menu pinned to the bottom edge.
///
/// It owns its motion: a preference-hosted overlay arrives without the transaction of the state
/// change that presented it, so an insertion/removal transition never animates. Instead the layer
/// slides in when it appears, and when `visible` turns false it slides out, then calls `onHidden`
/// so the presenter unmounts it.
private struct ActionMenuLayer<Menu: View>: View {
    let visible: Bool
    let onDismiss: () -> Void
    let onHidden: () -> Void
    let menu: Menu

    @State private var shown = false
    @State private var drag: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full screen, ignoring safe areas; a tap anywhere outside the menu dismisses.
            Token.black80
                .opacity(shown ? 1 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
                .ui2Element("Dim")
            menu
                .padding(.horizontal, ActionMenuMotion.edgeInset)
                .padding(.bottom, ActionMenuMotion.edgeInset)
                .visualEffect { [shown, drag] effect, proxy in
                    effect.offset(y: (shown ? 0 : proxy.size.height) + drag)
                }
                // High priority: a pull that starts on a row drags the sheet; a tap (no movement past
                // `minimumDistance`) still reaches the row's button.
                .highPriorityGesture(
                    // pan-ok: a vertical drag-to-dismiss on the sheet, never a sideways pan.
                    DragGesture(minimumDistance: 4)
                        .onChanged { drag = ActionMenuMotion.dragOffset($0.translation.height) }
                        .onEnded { value in
                            if ActionMenuMotion.shouldDismiss(
                                translation: value.translation.height,
                                predicted: value.predictedEndTranslation.height
                            ) {
                                onDismiss()
                            } else {
                                withAnimation(ActionMenuMotion.slide) { drag = 0 }
                            }
                        }
                )
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape, onDismiss)
        }
        // The frame draws the menu 4pt above the screen's bottom edge, over the home indicator.
        .ignoresSafeArea(.container, edges: .bottom)
        .allowsHitTesting(visible)
        .onAppear {
            withAnimation(ActionMenuMotion.slide) { shown = true }
        }
        .onChange(of: visible) { _, nowVisible in
            // Re-presented mid slide-out: slide back up from wherever it is.
            guard !nowVisible else {
                withAnimation(ActionMenuMotion.slide) { shown = true; drag = 0 }
                return
            }
            withAnimation(ActionMenuMotion.slide) {
                shown = false
            } completion: {
                onHidden()
            }
        }
    }
}

/// The screen-level presentation: under a `.ui2OverlayHost()` the layer is handed up to the
/// shell; elsewhere (previews, capture) it overlays the view in place. The layer stays mounted
/// after `isPresented` turns false until its slide-out finishes.
private struct HostableActionMenuPresentation<Menu: View>: ViewModifier {
    let isPresented: Bool
    let onDismiss: () -> Void
    let onHidden: () -> Void
    let menu: Menu

    @Environment(\.ui2HostsOverlays) private var hosted
    @State private var mounted = false

    private var layer: some View {
        ActionMenuLayer(visible: isPresented, onDismiss: onDismiss, onHidden: { mounted = false; onHidden() }, menu: menu)
    }

    func body(content: Content) -> some View {
        Group {
            if hosted {
                content.preference(
                    key: UI2HostedOverlayKey.self,
                    value: mounted ? UI2HostedOverlay(view: AnyView(layer), transition: .identity) : nil
                )
            } else {
                content.overlay {
                    if mounted { layer }
                }
            }
        }
        .onChange(of: isPresented, initial: true) { _, presented in
            if presented { mounted = true }
        }
    }
}
