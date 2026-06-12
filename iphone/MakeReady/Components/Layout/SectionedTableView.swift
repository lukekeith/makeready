//
//  SectionedTableView.swift
//  MakeReady
//
//  UITableView wrapper with native alphabet section index scrubber
//  Allows SwiftUI content in cells via UIHostingConfiguration
//

import SwiftUI
import UIKit

/// A UITableView wrapper that provides native section index (alphabet scrubber)
/// while allowing SwiftUI views for cell content
struct SectionedTableView<Item: Identifiable & Hashable, Content: View>: UIViewControllerRepresentable {
    let sections: [(String, [Item])]
    let sectionIndexTitles: [String]
    let topInset: CGFloat
    let swipeState: SwipeState?
    @ViewBuilder let content: (Item) -> Content

    // Callbacks for height measurement
    var onScroll: (() -> Void)?
    var onFirstCellHeightMeasured: ((CGFloat) -> Void)?
    var onSectionHeaderHeightMeasured: ((CGFloat) -> Void)?
    
    init(
        sections: [(String, [Item])],
        sectionIndexTitles: [String]? = nil,
        topInset: CGFloat = 80,
        swipeState: SwipeState? = nil,
        onScroll: (() -> Void)? = nil,
        onFirstCellHeightMeasured: ((CGFloat) -> Void)? = nil,
        onSectionHeaderHeightMeasured: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.sections = sections
        self.sectionIndexTitles = sectionIndexTitles ?? sections.map { $0.0 }
        self.topInset = topInset
        self.swipeState = swipeState
        self.onScroll = onScroll
        self.onFirstCellHeightMeasured = onFirstCellHeightMeasured
        self.onSectionHeaderHeightMeasured = onSectionHeaderHeightMeasured
        self.content = content
    }
    
    func makeUIViewController(context: Context) -> UITableViewController {
        let controller = UITableViewController(style: .plain)
        let tableView = controller.tableView!
        
        // Transparent background
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        
        // Register cell
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        // Set data source and delegate
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        
        // Section index styling
        tableView.sectionIndexColor = UIColor(Color.accentBlue)
        tableView.sectionIndexBackgroundColor = .clear
        tableView.sectionIndexTrackingBackgroundColor = .clear
        
        // Content inset for search field
        tableView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 16, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
        
        return controller
    }
    
    func updateUIViewController(_ controller: UITableViewController, context: Context) {
        context.coordinator.sections = sections
        context.coordinator.sectionIndexTitles = sectionIndexTitles
        context.coordinator.content = content
        context.coordinator.onScroll = onScroll
        context.coordinator.onFirstCellHeightMeasured = onFirstCellHeightMeasured
        context.coordinator.onSectionHeaderHeightMeasured = onSectionHeaderHeightMeasured

        // Lock/unlock scrolling based on swipe state
        if let swipeState = swipeState {
            controller.tableView.isScrollEnabled = !swipeState.isSwiping
        }

        // Update content inset when topInset changes (sync with SwiftUI animation)
        let newInset = UIEdgeInsets(top: topInset, left: 0, bottom: 16, right: 0)
        let oldInset = controller.tableView.contentInset.top

        if oldInset != newInset.top {
            let tableView = controller.tableView!
            let oldOffset = tableView.contentOffset.y

            // Match SwiftUI's easeInOut 0.5s animation
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                options: [.curveEaseInOut]
            ) {
                tableView.contentInset = newInset
                tableView.scrollIndicatorInsets = newInset

                // Adjust scroll offset to compensate for inset change
                // This keeps the visible content in the same position
                let insetDelta = newInset.top - oldInset
                tableView.contentOffset.y = oldOffset + insetDelta
            }
        }

        controller.tableView.reloadData()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            sections: sections,
            sectionIndexTitles: sectionIndexTitles,
            content: content,
            onScroll: onScroll,
            onFirstCellHeightMeasured: onFirstCellHeightMeasured,
            onSectionHeaderHeightMeasured: onSectionHeaderHeightMeasured
        )
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var sections: [(String, [Item])]
        var sectionIndexTitles: [String]
        var content: (Item) -> Content
        var onScroll: (() -> Void)?
        var onFirstCellHeightMeasured: ((CGFloat) -> Void)?
        var onSectionHeaderHeightMeasured: ((CGFloat) -> Void)?
        
        private var hasScrolled = false
        private var hasReportedFirstCellHeight = false
        private var hasReportedSectionHeaderHeight = false
        
        init(
            sections: [(String, [Item])],
            sectionIndexTitles: [String],
            content: @escaping (Item) -> Content,
            onScroll: (() -> Void)?,
            onFirstCellHeightMeasured: ((CGFloat) -> Void)?,
            onSectionHeaderHeightMeasured: ((CGFloat) -> Void)?
        ) {
            self.sections = sections
            self.sectionIndexTitles = sectionIndexTitles
            self.content = content
            self.onScroll = onScroll
            self.onFirstCellHeightMeasured = onFirstCellHeightMeasured
            self.onSectionHeaderHeightMeasured = onSectionHeaderHeightMeasured
        }
        
        // MARK: - DataSource
        
        func numberOfSections(in tableView: UITableView) -> Int {
            sections.count
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            sections[section].1.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            let item = sections[indexPath.section].1[indexPath.row]
            
            cell.contentConfiguration = UIHostingConfiguration {
                content(item)
            }
            .margins(.all, 0)
            .background(.clear)
            
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            
            return cell
        }
        
        // MARK: - Section Headers
        
        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            let letter = sections[section].0
            guard !letter.isEmpty else { return nil }
            
            let hostingController = UIHostingController(rootView:
                Text(letter)
                    .font(Typography.s16Bold)
                    .foregroundColor(.white50)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            )
            hostingController.view.backgroundColor = .clear
            return hostingController.view
        }
        
        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            let letter = sections[section].0
            return letter.isEmpty ? 0 : 28
        }
        
        // MARK: - Section Index
        
        func sectionIndexTitles(for tableView: UITableView) -> [String]? {
            sectionIndexTitles
        }
        
        func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
            // Find the section that matches this title
            sections.firstIndex { $0.0 == title } ?? 0
        }
        
        // MARK: - Scroll Detection
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Detect when user starts scrolling
            if !hasScrolled && scrollView.isDragging {
                hasScrolled = true
                print("👆 User started scrolling (UITableView)")
                onScroll?()
            }
            
            guard let tableView = scrollView as? UITableView else { return }
            
            // Measure first cell height after scrolling starts
            if hasScrolled && !hasReportedFirstCellHeight,
               let firstCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) {
                let height = firstCell.frame.height
                if height > 0 {
                    hasReportedFirstCellHeight = true
                    print("📐 First cell height measured (UITableView): \(height)")
                    onFirstCellHeightMeasured?(height)
                }
            }
            
            // Measure section header height
            if hasScrolled && !hasReportedSectionHeaderHeight,
               let headerView = tableView.headerView(forSection: 0) {
                let headerHeight = headerView.frame.height
                if headerHeight > 0 {
                    hasReportedSectionHeaderHeight = true
                    print("📐 Section header height measured (UITableView): \(headerHeight)")
                    onSectionHeaderHeightMeasured?(headerHeight)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()
        
        SectionedTableView(
            sections: [
                ("A", [PreviewItem(name: "Alice"), PreviewItem(name: "Adam")]),
                ("B", [PreviewItem(name: "Bob"), PreviewItem(name: "Beth")]),
                ("C", [PreviewItem(name: "Charlie"), PreviewItem(name: "Carol")]),
            ]
        ) { item in
            HStack {
                Text(item.name)
                    .font(Typography.s17Bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(16)
        }
    }
}

private struct PreviewItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
}
