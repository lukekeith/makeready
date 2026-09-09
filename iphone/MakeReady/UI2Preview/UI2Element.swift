//
//  UI2Element.swift
//  UI2Preview — the UI 2.0 preview module
//
//  The element map: how a 2.0 component tells the capture browser what its own parts
//  are, and where they landed.
//
//  The 1.0 side of /components gets element context for a comment by hit-testing the
//  live Vue twin in a hidden iframe (ComponentsLayout.jsx). A 2.0 component has no web
//  twin — its render is a simulator screenshot — so the geometry has to come out of the
//  SwiftUI layout pass itself. Each component annotates its own anatomy with
//  `.ui2Element("Title")`, the capture harness wraps the view in `.ui2ElementMap(_:)`,
//  and CaptureRunner writes the resolved rects beside the PNG as `*.elements.json`.
//
//  The names ARE the contract's §2 anatomy names — that vocabulary is what a comment
//  ends up carrying, and what /component-resolve reads back.
//
//  Cost when not capturing: one anchor preference per annotated part, collected by
//  nobody. Nothing here renders.
//

import SwiftUI

/// One annotated part of a component and the rect it occupied, in the coordinate space
/// of the view `ui2ElementMap(_:)` was applied to.
struct UI2ElementRect {
    let name: String
    let rect: CGRect
}

/// The sink `ui2ElementMap(_:)` writes into.
///
/// Deliberately a plain reference type, NOT observable: it is mutated from inside a
/// `GeometryReader` body during the layout pass, and a published mutation there would
/// invalidate the view being measured. Nothing reads it until the pass is over.
final class UI2ElementMap {
    /// The measured view's own size — the frame every rect is expressed against.
    private(set) var size: CGSize = .zero
    private(set) var elements: [UI2ElementRect] = []

    func record(size: CGSize, elements: [UI2ElementRect]) {
        self.size = size
        self.elements = elements
    }
}

/// A part's name paired with its still-unresolved bounds.
struct UI2ElementAnchor {
    let name: String
    let anchor: Anchor<CGRect>
}

/// Carries every annotated part up to whichever ancestor is collecting.
enum UI2ElementPreferenceKey: PreferenceKey {
    static let defaultValue: [UI2ElementAnchor] = []

    static func reduce(value: inout [UI2ElementAnchor], nextValue: () -> [UI2ElementAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {

    /// Name this view as one of the component's parts.
    ///
    /// Applied at the anatomy boundaries a comment would want to name — the root, each
    /// named slot, each repeated item. Nesting is not declared: the browser derives it
    /// from rect containment, so a `GlyphButton` that names itself is correctly reported
    /// as sitting inside the `Trailing` group of whatever consumer placed it.
    ///
    /// `transformAnchorPreference`, NOT `anchorPreference`: the latter SETS the key's
    /// value for the view it is applied to, discarding whatever the view's own children
    /// contributed — so a component that named its root erased every part inside it and
    /// arrived with exactly one element. Transforming appends this view's bounds to what
    /// its subtree already produced, which is what makes nesting survive.
    func ui2Element(_ name: String) -> some View {
        transformAnchorPreference(key: UI2ElementPreferenceKey.self, value: .bounds) { value, anchor in
            value.append(UI2ElementAnchor(name: name, anchor: anchor))
        }
    }

    /// Collect every `ui2Element` beneath this view into `map` during the layout pass.
    ///
    /// Capture-harness only (CaptureRunner). The overlay is an empty `Color.clear` that
    /// takes no hits and changes no layout — an overlay is sized by its content, so the
    /// measured view is the same view the snapshot renders.
    func ui2ElementMap(_ map: UI2ElementMap) -> some View {
        overlayPreferenceValue(UI2ElementPreferenceKey.self) { anchors in
            GeometryReader { proxy -> Color in
                map.record(
                    size: proxy.size,
                    elements: anchors.map { UI2ElementRect(name: $0.name, rect: proxy[$0.anchor]) }
                )
                return Color.clear
            }
            .allowsHitTesting(false)
        }
    }
}
