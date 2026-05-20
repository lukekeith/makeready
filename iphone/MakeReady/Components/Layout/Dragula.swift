//
//  Dragula.swift
//  MakeReady
//
//  Vendored from https://github.com/mufasaYC/Dragula (MIT License)
//  Created by Mustafa Yusuf on 05/06/25.
//  Patched: UIDragPreviewParameters.backgroundColor = .clear for dark backgrounds
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Protocols

/// A protocol representing a section that contains drag-and-droppable items.
public protocol DragulaSection: Identifiable {
    associatedtype Item: DragulaItem
    var items: [Item] { get set }
}

/// A protocol for individual drag-and-droppable items.
public protocol DragulaItem: Identifiable {
    var isDraggable: Bool { get }
    func getItemProvider() -> NSItemProvider
}

extension DragulaItem {
    public var isDraggable: Bool { true }
    public func getItemProvider() -> NSItemProvider { .init() }
}

// MARK: - DragulaView (Flat List)

public struct DragulaView<Card: View, DropView: View, Item: DragulaItem>: View {

    @State private var draggedItems: [Item] = []
    @Binding var items: [Item]
    private let card: (Item) -> Card
    private let dropView: ((Item) -> DropView)?
    private let dropCompleted: () -> Void
    private let supportedUTTypes: [UTType] = []

    public init(
        items: Binding<[Item]>,
        @ViewBuilder card: @escaping (Item) -> Card,
        @ViewBuilder dropView: @escaping (Item) -> DropView,
        dropCompleted: @escaping () -> Void
    ) {
        self._items = items
        self.card = card
        self.dropView = dropView
        self.dropCompleted = dropCompleted
    }

    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    public var body: some View {
        ForEach(items) { item in
            if Self.isPreview {
                card(item)
            } else {
                card(item)
                    .hidden(item.isDraggable)
                    .overlay {
                        if item.isDraggable {
                            DraggableView(
                                preview: { card(item) },
                                dropView: { dropView?(item) },
                                itemProvider: { item.getItemProvider() },
                                onDragWillBegin: { self.draggedItems.append(item) },
                                onDragWillEnd: {
                                    self.draggedItems = []
                                    self.dropCompleted()
                                }
                            )
                        }
                    }
                    .onDrop(
                        of: supportedUTTypes,
                        delegate: DragulaDropDelegate(
                            item: item,
                            items: $items,
                            draggedItems: $draggedItems
                        )
                    )
            }
        }
    }
}

// MARK: - DragulaSectionedView

public struct DragulaSectionedView<Header: View, Card: View, DropView: View, Section: DragulaSection>: View {

    @Binding private var sections: [Section]
    @Binding private var items: [Section.Item]
    @State private var draggedItems: [Section.Item] = []
    private let header: (Section) -> Header
    private let card: (Section.Item) -> Card
    private let dropView: ((Section.Item) -> DropView)?
    private let dropCompleted: () -> Void
    private let supportedUTTypes: [UTType] = []

    public init(
        sections: Binding<[Section]>,
        @ViewBuilder header: @escaping (Section) -> Header,
        @ViewBuilder card: @escaping (Section.Item) -> Card,
        @ViewBuilder dropView: @escaping (Section.Item) -> DropView,
        dropCompleted: @escaping () -> Void
    ) {
        self._sections = sections
        self._items = .constant([])
        self.header = header
        self.card = card
        self.dropView = dropView
        self.dropCompleted = dropCompleted
    }

    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    public var body: some View {
        ForEach(sections) { section in
            header(section)
                .onDrop(
                    of: supportedUTTypes,
                    delegate: DragulaSectionDropDelegate(
                        item: nil,
                        sectionID: section.id,
                        sections: $sections,
                        draggedItems: $draggedItems
                    )
                )

            ForEach(section.items) { item in
                if Self.isPreview {
                    card(item)
                } else {
                    card(item)
                        .hidden(item.isDraggable)
                        .overlay {
                            if item.isDraggable {
                                DraggableView(
                                    preview: { card(item) },
                                    dropView: { dropView?(item) },
                                    itemProvider: { item.getItemProvider() },
                                    onDragWillBegin: { self.draggedItems.append(item) },
                                    onDragWillEnd: {
                                        self.draggedItems = []
                                        self.dropCompleted()
                                    }
                                )
                            }
                        }
                        .onDrop(
                            of: supportedUTTypes,
                            delegate: DragulaSectionDropDelegate(
                                item: item,
                                sectionID: section.id,
                                sections: $sections,
                                draggedItems: $draggedItems
                            )
                        )
                }
            }
        }
    }
}

// MARK: - DraggableView (UIKit bridge)

struct DraggableView<Preview: View, DropView: View>: UIViewRepresentable {

    @Environment(\.dragPreviewCornerRadius) private var dragPreviewCornerRadius

    private let itemProvider: () -> NSItemProvider
    private let onDragWillBegin: (() -> Void)?
    private let onDragWillEnd: (() -> Void)?
    private let preview: () -> Preview
    private let dropView: () -> DropView

    init(
        @ViewBuilder preview: @escaping () -> Preview,
        @ViewBuilder dropView: @escaping () -> DropView,
        itemProvider: @escaping () -> NSItemProvider,
        onDragWillBegin: (() -> Void)?,
        onDragWillEnd: (() -> Void)?
    ) {
        self.preview = preview
        self.dropView = dropView
        self.itemProvider = itemProvider
        self.onDragWillBegin = onDragWillBegin
        self.onDragWillEnd = onDragWillEnd
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewHosting: UIHostingController<Preview>?
        var dropViewHosting: UIHostingController<DropView>?
    }

    func makeUIView(context: Context) -> DraggableUIView {
        let previewHC = UIHostingController(rootView: preview())
        previewHC.view.backgroundColor = .clear
        context.coordinator.previewHosting = previewHC

        let dropViewHC = UIHostingController(rootView: dropView())
        dropViewHC.view.backgroundColor = .clear
        context.coordinator.dropViewHosting = dropViewHC

        let draggableView = DraggableUIView(
            preview: previewHC.view,
            dropView: dropViewHC.view,
            itemProvider: itemProvider,
            onDragWillBegin: onDragWillBegin,
            onDragWillEnd: onDragWillEnd
        )
        draggableView.dragPreviewCornerRadius = dragPreviewCornerRadius
        return draggableView
    }

    func updateUIView(_ uiView: DraggableUIView, context: Context) {
        uiView.dragPreviewCornerRadius = dragPreviewCornerRadius
        uiView.onDragWillBegin = onDragWillBegin
        uiView.onDragWillEnd = onDragWillEnd
        uiView.resetIfNeeded()
        context.coordinator.previewHosting?.rootView = preview()
        context.coordinator.previewHosting?.view.invalidateIntrinsicContentSize()
        context.coordinator.dropViewHosting?.rootView = dropView()
    }
}

extension DraggableView {
    final class DraggableUIView: UIView, UIDragInteractionDelegate {
        var dragPreviewCornerRadius: CGFloat = .zero
        private let previewView: UIView
        private let dropIndicatorView: UIView
        private let itemProvider: () -> NSItemProvider
        var onDragWillBegin: (() -> Void)?
        var onDragWillEnd: (() -> Void)?
        private var isDragging = false

        init(
            preview: UIView,
            dropView: UIView,
            itemProvider: @escaping () -> NSItemProvider,
            onDragWillBegin: (() -> Void)? = nil,
            onDragWillEnd: (() -> Void)? = nil
        ) {
            self.previewView = preview
            self.dropIndicatorView = dropView
            self.itemProvider = itemProvider
            self.onDragWillBegin = onDragWillBegin
            self.onDragWillEnd = onDragWillEnd

            super.init(frame: .zero)
            backgroundColor = .clear
            clipsToBounds = true
            isUserInteractionEnabled = true
            let dragInteraction = UIDragInteraction(delegate: self)
            previewView.addInteraction(dragInteraction)

            self.addSubview(previewView)
            self.addSubview(dropIndicatorView)
            self.dropIndicatorView.alpha = .zero
            self.previewView.translatesAutoresizingMaskIntoConstraints = false
            self.dropIndicatorView.translatesAutoresizingMaskIntoConstraints = false
            // Pin previewView to top only (not bottom) so content stays
            // top-aligned during animated frame changes. The hidden SwiftUI
            // card drives the frame animation; clipsToBounds clips overflow
            // during expand, and transparent gap below closes during collapse.
            NSLayoutConstraint.activate([
                self.previewView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                self.previewView.topAnchor.constraint(equalTo: self.topAnchor),
                self.previewView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                self.dropIndicatorView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                self.dropIndicatorView.topAnchor.constraint(equalTo: self.topAnchor),
                self.dropIndicatorView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                self.dropIndicatorView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Reset visual state if no drag is active (safety net for interrupted animations)
        func resetIfNeeded() {
            guard !isDragging else { return }
            // Remove in-flight UIKit animations that would override our property changes
            previewView.layer.removeAllAnimations()
            dropIndicatorView.layer.removeAllAnimations()
            previewView.isHidden = false
            previewView.alpha = 1
            dropIndicatorView.alpha = 0
            dropIndicatorView.isHidden = true
        }

        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
            isDragging = true
            onDragWillBegin?()
            return [UIDragItem(itemProvider: self.itemProvider())]
        }

        func dragInteraction(_ interaction: UIDragInteraction, itemsForAddingTo session: any UIDragSession, withTouchAt point: CGPoint) -> [UIDragItem] {
            onDragWillBegin?()
            return [UIDragItem(itemProvider: self.itemProvider())]
        }

        func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
            guard let sourceView = interaction.view else { return nil }

            let previewView = UIImageView(image: sourceView.snapshot())
            previewView.bounds = sourceView.bounds

            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(
                roundedRect: previewView.bounds,
                cornerRadius: dragPreviewCornerRadius
            )

            let target = UIDragPreviewTarget(container: sourceView.superview!, center: sourceView.center)
            return UITargetedDragPreview(view: previewView, parameters: parameters, target: target)
        }

        func dragInteraction(_ interaction: UIDragInteraction, willAnimateLiftWith animator: any UIDragAnimating, session: any UIDragSession) {
            self.dropIndicatorView.isHidden = false
            animator.addAnimations { [weak self] in
                self?.previewView.alpha = .zero
                self?.dropIndicatorView.alpha = 1
            }
        }

        func dragInteraction(_ interaction: UIDragInteraction, previewForCancelling item: UIDragItem, withDefault defaultPreview: UITargetedDragPreview) -> UITargetedDragPreview? {
            guard let view = interaction.view, let superview = view.superview else { return defaultPreview }
            let target = UIDragPreviewTarget(container: superview, center: view.center)
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            return UITargetedDragPreview(view: defaultPreview.view, parameters: parameters, target: target)
        }

        func dragInteraction(_ interaction: UIDragInteraction, prefersFullSizePreviewsFor session: any UIDragSession) -> Bool { true }

        func dragInteraction(_ interaction: UIDragInteraction, item: UIDragItem, willAnimateCancelWith animator: UIDragAnimating) {
            animator.addAnimations { [weak self] in
                self?.dropIndicatorView.alpha = .zero
                self?.previewView.alpha = 1
            }
            animator.addCompletion { [weak self] _ in
                self?.previewView.isHidden = false
                self?.dropIndicatorView.isHidden = true
            }
        }

        func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, willEndWith operation: UIDropOperation) {
            isDragging = false
            onDragWillEnd?()
        }

        func dragInteraction(_ interaction: UIDragInteraction, sessionIsRestrictedToDraggingApplication session: any UIDragSession) -> Bool { true }
    }
}

// MARK: - Drop Delegates

fileprivate struct DragulaDropDelegate<Item: DragulaItem>: DropDelegate {
    private let generator = UIImpactFeedbackGenerator(style: .rigid)
    private let item: Item
    @Binding private var items: [Item]
    @Binding private var draggedItems: [Item]
    private let animation: Animation = .spring

    init(item: Item, items: Binding<[Item]>, draggedItems: Binding<[Item]>) {
        self.item = item
        self._items = items
        self._draggedItems = draggedItems
    }

    func performDrop(info: DropInfo) -> Bool { !draggedItems.isEmpty }

    private func index(of item: Item) -> Int? {
        items.firstIndex(where: { $0.id == item.id })
    }

    func dropEntered(info: DropInfo) {
        guard !draggedItems.isEmpty,
              draggedItems.allSatisfy({ $0.id != item.id }) else { return }

        var didChange = false
        withAnimation(animation) {
            for dragged in draggedItems {
                if let from = index(of: dragged), let to = index(of: item) {
                    didChange = true
                    items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
        if didChange {
            generator.prepare()
            generator.impactOccurred()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .cancel) }
}

fileprivate struct DragulaSectionDropDelegate<Section: DragulaSection>: DropDelegate {
    private let generator = UIImpactFeedbackGenerator(style: .rigid)
    private let item: Section.Item?
    private let sectionID: Section.ID
    @Binding private var sections: [Section]
    @Binding private var draggedItems: [Section.Item]
    private let animation: Animation = .spring

    init(item: Section.Item?, sectionID: Section.ID, sections: Binding<[Section]>, draggedItems: Binding<[Section.Item]>) {
        self.item = item
        self.sectionID = sectionID
        self._sections = sections
        self._draggedItems = draggedItems
    }

    func performDrop(info: DropInfo) -> Bool { !draggedItems.isEmpty }

    private func sectionIndex(for item: Section.Item) -> Int? {
        sections.firstIndex { $0.items.contains { $0.id == item.id } }
    }

    private func itemIndex(for item: Section.Item) -> Int? {
        for section in sections {
            if let idx = section.items.firstIndex(where: { $0.id == item.id }) { return idx }
        }
        return nil
    }

    func dropEntered(info: DropInfo) {
        guard !draggedItems.isEmpty,
              draggedItems.allSatisfy({ $0.id != item?.id }) else { return }

        let toSectionIndex: Int
        if let item, let idx = sectionIndex(for: item) { toSectionIndex = idx }
        else if let idx = sections.firstIndex(where: { $0.id == sectionID }) { toSectionIndex = idx }
        else { return }

        var didChange = false
        withAnimation(animation) {
            for draggedItem in draggedItems {
                if let fromSec = sectionIndex(for: draggedItem), let fromIdx = itemIndex(for: draggedItem) {
                    let toIdx = item.flatMap { itemIndex(for: $0) } ?? 0
                    if fromSec == toSectionIndex {
                        if fromIdx != toIdx {
                            didChange = true
                            sections[toSectionIndex].items.move(
                                fromOffsets: IndexSet(integer: fromIdx),
                                toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
                            )
                        }
                    } else {
                        didChange = true
                        sections[fromSec].items.remove(at: fromIdx)
                        sections[toSectionIndex].items.insert(draggedItem, at: toIdx)
                    }
                }
            }
        }
        if didChange {
            generator.prepare()
            generator.impactOccurred()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .cancel) }

    func validateDrop(info: DropInfo) -> Bool {
        if item == nil {
            let indices = Set(draggedItems.compactMap { sectionIndex(for: $0) })
            if indices.count == 1, let idx = indices.first, sections[idx].id == sectionID { return false }
        }
        return true
    }
}

// MARK: - Environment

private struct DragPreviewCornerRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = 12
}

extension EnvironmentValues {
    public var dragPreviewCornerRadius: CGFloat {
        get { self[DragPreviewCornerRadiusKey.self] }
        set { self[DragPreviewCornerRadiusKey.self] = newValue }
    }
}

// MARK: - Helpers

fileprivate extension View {
    @ViewBuilder
    func hidden(_ isHidden: Bool) -> some View {
        if isHidden { self.hidden() } else { self }
    }
}

fileprivate extension UIView {
    func snapshot() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { context in layer.render(in: context.cgContext) }
    }
}
