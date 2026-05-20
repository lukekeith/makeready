//
//  SplitMonthLayout.swift
//  MakeReady
//
//  Custom UICollectionViewLayout for the split-month calendar
//  Handles the collapsed grid view of the calendar
//

import UIKit
import SwiftUI

// MARK: - Week Separator Decoration View

class WeekSeparatorDecorationView: UICollectionReusableView {
    static let elementKind = "WeekSeparatorDecoration"

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Layout

class SplitMonthLayout: UICollectionViewLayout {

    // MARK: - Types

    enum Mode: Equatable {
        case collapsed
    }

    // Element kinds
    static let monthHeaderKind = "MonthHeader"
    static let weekdayHeaderKind = "WeekdayHeader"
    static let eventListKind = "EventList"

    // MARK: - Initialization

    override init() {
        super.init()
        register(WeekSeparatorDecorationView.self, forDecorationViewOfKind: WeekSeparatorDecorationView.elementKind)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        register(WeekSeparatorDecorationView.self, forDecorationViewOfKind: WeekSeparatorDecorationView.elementKind)
    }

    // MARK: - Configuration

    var mode: Mode = .collapsed
    var cellSize: CGSize = CGSize(width: 48, height: 56) // Cells with room for event indicators
    var monthHeaderHeight: CGFloat = 32  // Smaller inline month headers
    var weekdayHeaderHeight: CGFloat = 32
    var horizontalPadding: CGFloat = 16
    var monthSpacing: CGFloat = 0  // No extra spacing - continuous scroll

    // Callback to get day data for positioning
    var dayDataProvider: ((IndexPath) -> SplitCalendarDay?)?

    // MARK: - Cached Attributes

    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var cachedMonthHeaderAttributes: [Int: UICollectionViewLayoutAttributes] = [:]
    private var cachedSeparatorAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    // MARK: - Computed Properties

    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        return collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
    }

    private var cellWidth: CGFloat {
        return (contentWidth - horizontalPadding * 2) / 7
    }

    // MARK: - Layout Override

    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }

    override func prepare() {
        guard let collectionView = collectionView else { return }

        // Clear cache
        cachedAttributes.removeAll()
        cachedMonthHeaderAttributes.removeAll()
        cachedSeparatorAttributes.removeAll()

        let numberOfSections = collectionView.numberOfSections
        guard numberOfSections > 0 else {
            contentHeight = 0
            return
        }

        var yOffset: CGFloat = 0

        // Layout each section (month)
        for section in 0..<numberOfSections {
            let numberOfItems = collectionView.numberOfItems(inSection: section)
            guard numberOfItems > 0 else { continue }

            // Month header
            let monthHeaderAttributes = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: Self.monthHeaderKind,
                with: IndexPath(item: 0, section: section)
            )
            monthHeaderAttributes.frame = CGRect(
                x: horizontalPadding,
                y: yOffset,
                width: contentWidth - horizontalPadding * 2,
                height: monthHeaderHeight
            )
            cachedMonthHeaderAttributes[section] = monthHeaderAttributes

            yOffset += monthHeaderHeight

            // Calculate grid dimensions using row index from the day data
            var maxRowIndex = 0

            // Layout day cells using weekdayIndex and rowIndex from the data
            for item in 0..<numberOfItems {
                let indexPath = IndexPath(item: item, section: section)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)

                // Get the day data to find the correct column (weekdayIndex) and row
                if let day = dayDataProvider?(indexPath) {
                    let column = day.weekdayIndex
                    let row = day.rowIndex
                    maxRowIndex = max(maxRowIndex, row)

                    let cellY = yOffset + CGFloat(row) * cellSize.height
                    let cellX = horizontalPadding + CGFloat(column) * cellWidth

                    attributes.frame = CGRect(
                        x: cellX,
                        y: cellY,
                        width: cellWidth,
                        height: cellSize.height
                    )
                } else {
                    // Fallback: sequential layout
                    let column = item % 7
                    let row = item / 7
                    maxRowIndex = max(maxRowIndex, row)

                    let cellY = yOffset + CGFloat(row) * cellSize.height
                    let cellX = horizontalPadding + CGFloat(column) * cellWidth

                    attributes.frame = CGRect(
                        x: cellX,
                        y: cellY,
                        width: cellWidth,
                        height: cellSize.height
                    )
                }

                cachedAttributes.append(attributes)
            }

            // Calculate section height based on actual rows used
            let numberOfRows = maxRowIndex + 1
            let sectionHeight = CGFloat(numberOfRows) * cellSize.height

            // Create week separator lines at the bottom of each row (between rows)
            // Using decoration views which don't require data source involvement
            for row in 0..<numberOfRows {
                // Skip separator after last row (separator goes between weeks, not at bottom of section)
                if row == numberOfRows - 1 { continue }

                let separatorY = yOffset + CGFloat(row + 1) * cellSize.height
                let separatorIndexPath = IndexPath(
                    item: row,  // Use row index as item
                    section: section
                )
                let separatorAttributes = UICollectionViewLayoutAttributes(
                    forDecorationViewOfKind: WeekSeparatorDecorationView.elementKind,
                    with: separatorIndexPath
                )
                separatorAttributes.frame = CGRect(
                    x: horizontalPadding,
                    y: separatorY - 0.5,  // Center the 1px line on the boundary
                    width: contentWidth - horizontalPadding * 2,
                    height: 1
                )
                separatorAttributes.zIndex = -1  // Put behind cells
                cachedSeparatorAttributes.append(separatorAttributes)
            }

            yOffset += sectionHeight + monthSpacing
        }

        contentHeight = yOffset
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var visibleAttributes: [UICollectionViewLayoutAttributes] = []

        // Day cells
        for attributes in cachedAttributes {
            if attributes.frame.intersects(rect) {
                visibleAttributes.append(attributes)
            }
        }

        // Month headers
        for (_, attributes) in cachedMonthHeaderAttributes {
            if attributes.frame.intersects(rect) {
                visibleAttributes.append(attributes)
            }
        }

        // Week separators
        for attributes in cachedSeparatorAttributes {
            if attributes.frame.intersects(rect) {
                visibleAttributes.append(attributes)
            }
        }

        return visibleAttributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cachedAttributes.first { $0.indexPath == indexPath }
    }

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        switch elementKind {
        case Self.monthHeaderKind:
            return cachedMonthHeaderAttributes[indexPath.section]
        default:
            return nil
        }
    }

    override func layoutAttributesForDecorationView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        if elementKind == WeekSeparatorDecorationView.elementKind {
            return cachedSeparatorAttributes.first { $0.indexPath == indexPath }
        }
        return nil
    }

    // MARK: - Invalidation

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }
}
