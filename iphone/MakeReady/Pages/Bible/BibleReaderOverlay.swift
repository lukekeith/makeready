//
//  BibleReaderOverlay.swift
//  MakeReady
//
//  Pure UIKit Bible reader modal with 3 screens:
//  Books → Chapters → Verses
//  Presented as a bottom sheet with rounded top corners.
//

import UIKit
import SwiftUI

// MARK: - Navigation Screen

private enum BibleScreen {
    case books
    case chapters(BibleBookInfo)
    case verses(BibleBookInfo, Int)       // book, chapter
    case reader(BibleBookInfo, Int, Int)  // book, chapter, verse
    case search                           // search results
}

// MARK: - BibleReaderOverlay

final class BibleReaderOverlayView: UIView, UITextFieldDelegate, UITextViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    // MARK: - Properties

    private let overlayManager: OverlayManager
    private let onDismiss: () -> Void
    private let onVerseSelected: ((BibleBookInfo, Int, Int) -> Void)?  // book, chapter, verse (navigated to reader)
    private let onPassageConfirmed: ((BibleBookInfo, Int, Int, Int, String) -> Void)?  // book, chapter, verseStart, verseEnd, selectedText

    // Used passages tracking — books, chapters, and verses already used in the program
    private let usedBookNumbers: Set<Int>         // book numbers with any passage
    private let usedChapters: [Int: Set<Int>]     // bookNumber → set of chapter numbers
    private let usedVerses: [String: Set<Int>]    // "bookNumber-chapter" → set of verse numbers

    private var currentScreen: BibleScreen = .books
    private var selectedVersionId: String = {
        let code = AppState.shared.selectedBibleTranslation
        return AppState.shared.bibleTranslations.first(where: { $0.code == code })?.id ?? ""
    }()
    private var selectedVersionAbbrev: String = AppState.shared.selectedBibleTranslation

    private let modalBg = UIColor(red: 0x25/255, green: 0x29/255, blue: 0x36/255, alpha: 1)
    private let cellBg = UIColor(white: 1, alpha: 0.05)
    private let brandPurple = UIColor(red: 0x6C/255, green: 0x47/255, blue: 0xFF/255, alpha: 1)
    private let searchBarBg = UIColor(red: 0x0D/255, green: 0x10/255, blue: 0x1A/255, alpha: 0.8)

    // Search state
    private var searchResults: [SearchResultItem] = []
    private var matchedBooks: [MatchedBook] = []
    private var recentSearches: [RecentSearch] = []
    private var isSearchLoading = false
    private var isLoadingRecents = false
    private var searchTask: Task<Void, Never>?
    private var screenBeforeSearch: BibleScreen = .books
    /// True when the current `.reader` screen was entered by tapping a search result.
    /// Used by `backTapped` to return to the search results instead of the verses grid.
    private var enteredReaderFromSearch = false

    // MARK: - Subviews

    private let containerView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 16
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.clipsToBounds = true
        return v
    }()

    private let dragIndicator: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.3)
        v.layer.cornerRadius = 2.5
        return v
    }()

    // Search bar
    private let searchBarView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        return v
    }()
    private let versionButton = UIButton(type: .system)
    private let bookListButton = UIButton(type: .system)
    private let searchField = UITextField()
    private let searchIcon = UIButton(type: .system)

    // Subtitle row
    private let subtitleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let selectButton = UIButton(type: .system)

    // Search bar label (replaces text field in reader mode)
    private let searchLabel = UILabel()

    // Grid
    private var collectionView: UICollectionView!

    // Search results
    private let searchResultsTable = UITableView(frame: .zero, style: .plain)

    // Reader
    private let readerContainer = UIView()
    private let readerTextView = UITextView()
    private let verseCircleContainer = UIView()  // overlays left side, scrolls with text
    private var verseCircleViews: [Int: UIView] = [:]  // verseNumber → circle view
    private var verseRanges: [(verse: Int, range: NSRange)] = []  // verse → character range in text
    private var loadedVerses: [VerseCompact] = []
    private var versesGridCount: Int = 0  // actual verse count for the current chapter grid

    // Chapter swipe preview — pre-rendered adjacent chapters shown during drag
    private let chapterPreviewTextView = UITextView()
    private var nextChapterRendered: NSAttributedString?
    private var prevChapterRendered: NSAttributedString?
    private var activePreviewDirection: NavigationDirection?

    // MARK: - Init

    init(
        overlayManager: OverlayManager,
        onDismiss: @escaping () -> Void,
        onVerseSelected: ((BibleBookInfo, Int, Int) -> Void)? = nil,
        onPassageConfirmed: ((BibleBookInfo, Int, Int, Int, String) -> Void)? = nil,
        usedPassages: [PassageData] = []
    ) {
        self.overlayManager = overlayManager
        self.onDismiss = onDismiss
        self.onVerseSelected = onVerseSelected
        self.onPassageConfirmed = onPassageConfirmed

        // Build lookup sets from used passages
        var books = Set<Int>()
        var chapters: [Int: Set<Int>] = [:]
        var verses: [String: Set<Int>] = [:]
        for p in usedPassages {
            books.insert(p.bookNumber)
            chapters[p.bookNumber, default: []].insert(p.chapterStart)
            let key = "\(p.bookNumber)-\(p.chapterStart)"
            for v in p.verseStart...p.verseEnd {
                verses[key, default: []].insert(v)
            }
        }
        self.usedBookNumbers = books
        self.usedChapters = chapters
        self.usedVerses = verses

        super.init(frame: .zero)
        setupViews()
        setupDismissGesture()
        setupChapterSwipeGesture()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private let scrimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return v
    }()

    private func setupViews() {
        backgroundColor = .clear

        addSubview(scrimView)
        containerView.backgroundColor = modalBg
        addSubview(containerView)

        // Drag indicator
        containerView.addSubview(dragIndicator)

        // Search bar
        searchBarView.backgroundColor = searchBarBg
        containerView.addSubview(searchBarView)

        // Version button
        var versionConfig = UIButton.Configuration.filled()
        versionConfig.title = String(selectedVersionAbbrev.uppercased().prefix(4))
        versionConfig.baseBackgroundColor = brandPurple
        versionConfig.baseForegroundColor = .white
        versionConfig.cornerStyle = .fixed
        versionConfig.background.cornerRadius = 4
        versionConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        versionConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 10, weight: .bold)
            return out
        }
        versionButton.configuration = versionConfig
        versionButton.titleLabel?.lineBreakMode = .byClipping
        versionButton.titleLabel?.numberOfLines = 1
        versionButton.addTarget(self, action: #selector(versionTapped), for: .touchUpInside)
        searchBarView.addSubview(versionButton)

        // Book list button
        let bookListBg = UIView()
        bookListBg.backgroundColor = UIColor(white: 1, alpha: 0.2)
        bookListBg.layer.cornerRadius = 4
        bookListBg.isUserInteractionEnabled = false
        bookListButton.addSubview(bookListBg)
        let lineConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        bookListButton.setImage(UIImage(systemName: "text.justify.left", withConfiguration: lineConfig), for: .normal)
        bookListButton.tintColor = UIColor(red: 0xD9/255, green: 0xD9/255, blue: 0xD9/255, alpha: 1)
        bookListButton.addTarget(self, action: #selector(bookListTapped), for: .touchUpInside)
        searchBarView.addSubview(bookListButton)

        // Search field
        searchField.font = .systemFont(ofSize: 15)
        searchField.textColor = .white
        searchField.tintColor = .white
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Enter a reference, e g \u{201C}Romans 1:1\u{201D}",
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.5)]
        )
        searchField.returnKeyType = .search
        searchField.delegate = self
        searchBarView.addSubview(searchField)

        // Search icon
        let searchConfig = UIImage.SymbolConfiguration(pointSize: 14)
        searchIcon.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: searchConfig), for: .normal)
        searchIcon.tintColor = UIColor(white: 1, alpha: 0.5)
        searchIcon.isHidden = true
        searchIcon.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        searchBarView.addSubview(searchIcon)

        // Subtitle
        subtitleLabel.text = "Select a book or enter reference"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = UIColor(white: 1, alpha: 0.4)
        subtitleLabel.textAlignment = .center
        containerView.addSubview(subtitleLabel)

        // Back/close button
        let xConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        backButton.setImage(UIImage(systemName: "xmark", withConfiguration: xConfig), for: .normal)
        backButton.tintColor = UIColor(white: 1, alpha: 0.6)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        // Select button (visible only in reader mode)
        selectButton.setTitle("Select", for: .normal)
        selectButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        selectButton.tintColor = brandPurple
        selectButton.setTitleColor(brandPurple, for: .normal)
        selectButton.setTitleColor(brandPurple.withAlphaComponent(0.3), for: .disabled)
        selectButton.isHidden = true
        selectButton.isEnabled = false
        selectButton.addTarget(self, action: #selector(selectTapped), for: .touchUpInside)
        containerView.addSubview(backButton)

        // Collection view
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(BookCell.self, forCellWithReuseIdentifier: "BookCell")
        collectionView.register(NumberCell.self, forCellWithReuseIdentifier: "NumberCell")
        collectionView.register(SectionSpacer.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionSpacer")
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 40, right: 16)
        containerView.addSubview(collectionView)

        // Search label (hidden until reader mode — replaces text field)
        searchLabel.font = .systemFont(ofSize: 15)
        searchLabel.textColor = .white
        searchLabel.isHidden = true
        searchLabel.isUserInteractionEnabled = true
        let labelTap = UITapGestureRecognizer(target: self, action: #selector(bookListTapped))
        searchLabel.addGestureRecognizer(labelTap)
        searchBarView.addSubview(searchLabel)

        // Reader container (hidden until reader mode)
        readerContainer.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        readerContainer.isHidden = true
        readerContainer.clipsToBounds = true
        containerView.addSubview(readerContainer)
        containerView.addSubview(selectButton)

        // UITextView has its own scrolling
        readerTextView.isEditable = false
        readerTextView.isSelectable = true
        readerTextView.delegate = self
        readerTextView.isScrollEnabled = true
        readerTextView.alwaysBounceVertical = true
        readerTextView.showsVerticalScrollIndicator = true
        readerTextView.indicatorStyle = .white
        readerTextView.backgroundColor = .clear
        // Left inset: 16 margin + 24 circle + 8 gap = 48
        readerTextView.textContainerInset = UIEdgeInsets(top: 24, left: 48, bottom: 60, right: 20)
        readerTextView.tintColor = UIColor(red: 0xF4/255, green: 0xFF/255, blue: 0x76/255, alpha: 0.5)

        // Remove system text interactions so no selection handles, dismiss "×"
        // button, or edit menu appear. Selection is driven entirely by verse
        // circle taps and the text-area tap gesture below, which set
        // selectedRange programmatically — the tint highlight still renders.
        for interaction in readerTextView.interactions.reversed() {
            if interaction is UITextInteraction {
                readerTextView.removeInteraction(interaction)
            }
        }

        // Tap gesture on text area — maps tap position to the verse under the
        // finger and forwards to verseCircleTapped logic.
        let textTap = UITapGestureRecognizer(target: self, action: #selector(readerTextTapped(_:)))
        readerTextView.addGestureRecognizer(textTap)

        readerContainer.addSubview(readerTextView)

        // Preview text view for chapter swipe (behind main content)
        chapterPreviewTextView.isEditable = false
        chapterPreviewTextView.isSelectable = false
        chapterPreviewTextView.isScrollEnabled = false
        chapterPreviewTextView.backgroundColor = .clear
        chapterPreviewTextView.textContainerInset = readerTextView.textContainerInset
        chapterPreviewTextView.isHidden = true
        readerContainer.insertSubview(chapterPreviewTextView, belowSubview: readerTextView)

        // Verse circle container (overlays text view, scrolls in sync)
        verseCircleContainer.backgroundColor = .clear
        verseCircleContainer.isUserInteractionEnabled = true
        readerContainer.addSubview(verseCircleContainer)

        // Search results table (hidden until search mode)
        searchResultsTable.backgroundColor = .clear
        searchResultsTable.separatorStyle = .none
        searchResultsTable.dataSource = self
        searchResultsTable.delegate = self
        searchResultsTable.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        searchResultsTable.rowHeight = UITableView.automaticDimension
        searchResultsTable.estimatedRowHeight = 48
        searchResultsTable.isHidden = true
        searchResultsTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Self.defaultResultsBottomInset, right: 0)
        containerView.addSubview(searchResultsTable)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Bottom inset used when no keyboard is visible — preserves the small
    /// gap below the last result row.
    private static let defaultResultsBottomInset: CGFloat = 40

    /// Track the keyboard and push the search results table's bottom inset up
    /// so rows below the keyboard stay scrollable. Uses the keyboard's own
    /// animation curve/duration so the inset change stays in lock-step with
    /// the keyboard motion.
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }

        // Only adjust while the results table is actually visible.
        guard !searchResultsTable.isHidden else { return }

        // Convert the keyboard frame into this view's coordinate space so the
        // overlap math is correct regardless of where we sit in the window
        // (and regardless of the container's current origin during its
        // slide-up animation).
        let kbFrameInSelf = convert(endFrame, from: nil)
        let tableFrameInSelf = searchResultsTable.convert(searchResultsTable.bounds, to: self)
        let overlap = max(0, tableFrameInSelf.maxY - kbFrameInSelf.minY)
        let targetBottomInset = overlap > 0
            ? overlap + 16
            : Self.defaultResultsBottomInset

        let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.searchResultsTable.contentInset.bottom = targetBottomInset
            self.searchResultsTable.verticalScrollIndicatorInsets.bottom = targetBottomInset
        }
    }

    // MARK: - Swipe to Dismiss

    private var dismissPanStartY: CGFloat = 0

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        let location = pan.location(in: containerView)

        // Chapter swipe gesture — horizontal, only in reader mode
        if pan === chapterSwipePan {
            guard case .reader = currentScreen else { return false }
            guard !isChapterTransitioning else { return false }
            return abs(velocity.x) > abs(velocity.y) && abs(velocity.x) > 50
        }

        // Dismiss gesture — must be a downward swipe from header
        guard velocity.y > abs(velocity.x) && velocity.y > 0 else { return false }

        let headerHeight: CGFloat = 90
        return location.y <= headerHeight
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    private func setupDismissGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        pan.delegate = self
        containerView.addGestureRecognizer(pan)
    }

    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)

        // Only allow downward drag
        guard translation.y > 0 || gesture.state != .changed else { return }

        switch gesture.state {
        case .began:
            dismissPanStartY = containerView.frame.origin.y

        case .changed:
            let newY = max(dismissPanStartY, dismissPanStartY + translation.y)
            containerView.frame.origin.y = newY
            // Fade scrim proportionally
            let totalDistance = bounds.height - dismissPanStartY
            let progress = min(max(translation.y / totalDistance, 0), 1)
            scrimView.alpha = 1 - progress

        case .ended, .cancelled:
            if translation.y > 150 || velocity.y > 800 {
                // Dismiss
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
                    self.containerView.frame.origin.y = self.bounds.height
                    self.scrimView.alpha = 0
                } completion: { _ in
                    self.removeFromSuperview()
                    self.onDismiss()
                }
            } else {
                // Snap back
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9,
                               initialSpringVelocity: 0, options: []) {
                    self.containerView.frame.origin.y = self.dismissPanStartY
                    self.scrimView.alpha = 1
                }
            }

        default:
            break
        }
    }

    // MARK: - Chapter Swipe Navigation

    private var chapterSwipePan: UIPanGestureRecognizer!
    private var isChapterTransitioning = false

    private func setupChapterSwipeGesture() {
        chapterSwipePan = UIPanGestureRecognizer(target: self, action: #selector(handleChapterSwipe(_:)))
        chapterSwipePan.delegate = self
        readerContainer.addGestureRecognizer(chapterSwipePan)
    }

    /// Returns the (book, chapter) for the next or previous chapter, crossing book
    /// boundaries when needed. Returns nil at Genesis 1 (backward) or Revelation 22 (forward).
    private func adjacentChapter(from book: BibleBookInfo, chapter: Int, direction: NavigationDirection) -> (BibleBookInfo, Int)? {
        if direction == .forward {
            if chapter < book.chapters {
                return (book, chapter + 1)
            }
            // Next book
            if let nextBook = bibleBooks.first(where: { $0.id == book.id + 1 }) {
                return (nextBook, 1)
            }
            return nil // Revelation 22 — no next
        } else {
            if chapter > 1 {
                return (book, chapter - 1)
            }
            // Previous book, last chapter
            if let prevBook = bibleBooks.first(where: { $0.id == book.id - 1 }) {
                return (prevBook, prevBook.chapters)
            }
            return nil // Genesis 1 — no previous
        }
    }

    @objc private func handleChapterSwipe(_ gesture: UIPanGestureRecognizer) {
        guard case .reader(let book, let chapter, _) = currentScreen else { return }

        let translation = gesture.translation(in: readerContainer)
        let velocity = gesture.velocity(in: readerContainer)
        let width = readerContainer.bounds.width

        switch gesture.state {
        case .began:
            activePreviewDirection = nil

        case .changed:
            let direction: NavigationDirection = translation.x < 0 ? .forward : .backward
            guard adjacentChapter(from: book, chapter: chapter, direction: direction) != nil else {
                // No adjacent chapter — rubber-band at 30%, no preview
                hideChapterPreview()
                readerTextView.transform = CGAffineTransform(translationX: translation.x * 0.3, y: 0)
                verseCircleContainer.transform = readerTextView.transform
                readerTextView.alpha = 1
                verseCircleContainer.alpha = 1
                return
            }

            // Set up preview for this direction
            if activePreviewDirection != direction {
                let previewContent = direction == .forward ? nextChapterRendered : prevChapterRendered
                if let content = previewContent {
                    chapterPreviewTextView.attributedText = content
                    chapterPreviewTextView.contentOffset = .zero
                    chapterPreviewTextView.isHidden = false
                    activePreviewDirection = direction
                } else {
                    chapterPreviewTextView.isHidden = true
                    activePreviewDirection = nil
                }
            }

            // Progress: 0 = no drag, 1 = full screen width
            let progress = min(abs(translation.x) / width, 1.0)

            // Current content: moves with finger, fades out proportionally
            readerTextView.transform = CGAffineTransform(translationX: translation.x, y: 0)
            verseCircleContainer.transform = readerTextView.transform
            readerTextView.alpha = 1 - progress
            verseCircleContainer.alpha = 1 - progress

            // Preview: slides in from the edge, fades in proportionally
            if activePreviewDirection != nil {
                let previewOffset: CGFloat = direction == .forward ? width + translation.x : -width + translation.x
                chapterPreviewTextView.transform = CGAffineTransform(translationX: previewOffset, y: 0)
                chapterPreviewTextView.alpha = progress
            }

        case .ended, .cancelled:
            let swipedLeft = translation.x < -width * 0.3 || velocity.x < -500
            let swipedRight = translation.x > width * 0.3 || velocity.x > 500
            let direction: NavigationDirection = swipedLeft ? .forward : .backward

            if (swipedLeft || swipedRight),
               let (nextBook, nextChapter) = adjacentChapter(from: book, chapter: chapter, direction: direction) {
                completeChapterTransition(
                    to: nextBook, chapter: nextChapter, direction: direction
                )
            } else {
                // Snap back
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                    self.readerTextView.transform = .identity
                    self.verseCircleContainer.transform = .identity
                    self.readerTextView.alpha = 1
                    self.verseCircleContainer.alpha = 1
                    self.chapterPreviewTextView.alpha = 0
                    if let dir = self.activePreviewDirection {
                        let snapBack: CGFloat = dir == .forward ? width : -width
                        self.chapterPreviewTextView.transform = CGAffineTransform(translationX: snapBack, y: 0)
                    }
                } completion: { _ in
                    self.hideChapterPreview()
                }
            }

        default:
            break
        }
    }

    private func hideChapterPreview() {
        chapterPreviewTextView.isHidden = true
        chapterPreviewTextView.transform = .identity
        chapterPreviewTextView.alpha = 1
        activePreviewDirection = nil
    }

    private func completeChapterTransition(to book: BibleBookInfo, chapter: Int, direction: NavigationDirection) {
        isChapterTransitioning = true
        let width = readerContainer.bounds.width
        let outgoingEnd: CGFloat = direction == .forward ? -width : width

        // Animate from current drag positions — outgoing fades to 0, incoming fades to 1
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.readerTextView.transform = CGAffineTransform(translationX: outgoingEnd, y: 0)
            self.verseCircleContainer.transform = self.readerTextView.transform
            self.readerTextView.alpha = 0
            self.verseCircleContainer.alpha = 0
            self.chapterPreviewTextView.transform = .identity
            self.chapterPreviewTextView.alpha = 1
        } completion: { _ in
            // Reset outgoing views but keep them hidden — preview stays visible
            self.readerTextView.transform = .identity
            self.readerTextView.alpha = 0
            self.verseCircleContainer.alpha = 0

            // Seed the real text view with the preview content so there's no jump
            // when we swap from preview → real reader
            self.readerTextView.attributedText = self.chapterPreviewTextView.attributedText
            self.readerTextView.contentOffset = .zero

            // Now swap: show real content, hide preview
            self.readerTextView.alpha = 1
            self.hideChapterPreview()

            // Update state and load full content (verse circles, ranges, etc.)
            self.currentScreen = .reader(book, chapter, 1)
            self.searchLabel.text = "\(book.name) \(chapter):1"
            self.subtitleLabel.text = "Highlight passage"
            self.selectButton.isEnabled = false
            self.loadReaderContent(book: book, chapter: chapter, scrollToVerse: 1)
            self.isChapterTransitioning = false
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        scrimView.frame = bounds

        let safeTop = safeAreaInsets.top
        let topOffset = safeTop + 10

        containerView.frame = CGRect(x: 0, y: topOffset, width: bounds.width, height: bounds.height - topOffset)

        // Drag indicator
        dragIndicator.frame = CGRect(x: (bounds.width - 36) / 2, y: 10, width: 36, height: 5)

        // Search bar
        let searchBarY: CGFloat = 27
        let searchBarH: CGFloat = 40
        searchBarView.frame = CGRect(x: 16, y: searchBarY, width: bounds.width - 32, height: searchBarH)

        // Layout search bar contents — fixed width so button doesn't resize on version change
        let vbW: CGFloat = 48
        versionButton.frame = CGRect(x: 8, y: (searchBarH - 24) / 2, width: vbW, height: 24)

        bookListButton.frame = CGRect(x: versionButton.frame.maxX + 8, y: (searchBarH - 24) / 2, width: 24, height: 24)
        if let bg = bookListButton.subviews.first(where: { !($0 is UIImageView) }) {
            bg.frame = bookListButton.bounds
        }

        let fieldX = bookListButton.frame.maxX + 8
        let fieldW = searchBarView.bounds.width - fieldX - (searchIcon.isHidden ? 8 : 32)
        searchField.frame = CGRect(x: fieldX, y: 0, width: fieldW, height: searchBarH)
        searchLabel.frame = CGRect(x: fieldX, y: 0, width: fieldW, height: searchBarH)

        searchIcon.frame = CGRect(x: searchBarView.bounds.width - 32, y: (searchBarH - 24) / 2, width: 24, height: 24)

        // Subtitle row
        let subtitleY = searchBarView.frame.maxY + 16
        subtitleLabel.frame = CGRect(x: 0, y: subtitleY, width: bounds.width, height: 18)
        backButton.frame = CGRect(x: 16, y: subtitleY - 2, width: 24, height: 24)
        selectButton.sizeToFit()
        selectButton.frame = CGRect(x: bounds.width - selectButton.frame.width - 16, y: subtitleY - 2, width: selectButton.frame.width, height: 24)

        // Collection view
        let gridY = subtitleY + 30
        collectionView.frame = CGRect(x: 0, y: gridY, width: bounds.width, height: containerView.bounds.height - gridY)

        // Reader container (below subtitle, fills remaining space)
        readerContainer.frame = CGRect(x: 0, y: gridY - 4, width: bounds.width, height: containerView.bounds.height - gridY + 4)
        readerTextView.frame = readerContainer.bounds
        chapterPreviewTextView.frame = readerContainer.bounds

        // Search results table (same frame as collection view)
        searchResultsTable.frame = CGRect(x: 0, y: gridY, width: bounds.width, height: containerView.bounds.height - gridY)
    }

    // MARK: - Update Version Display

    func updateVersion(_ abbrev: String) {
        selectedVersionAbbrev = abbrev
        versionButton.configuration?.title = String(abbrev.uppercased().prefix(4))

        // Update the centralized state so all readers react
        AppState.shared.selectedBibleTranslation = abbrev

        // If currently in the reader, reload content with the new translation
        if case .reader(let book, let chapter, let verse) = currentScreen {
            loadReaderContent(book: book, chapter: chapter, scrollToVerse: verse)
        }
    }

    func clearVersionDropdown() {
        versionDropdown = nil
    }

    // MARK: - Navigation

    private enum NavigationDirection {
        case forward  // books → chapters → verses (slide left)
        case backward // verses → chapters → books (slide right)
    }

    private func navigateTo(_ screen: BibleScreen, direction: NavigationDirection = .forward, animated: Bool = true) {
        let previousScreen = currentScreen
        var wasReader = false
        if case .reader = previousScreen { wasReader = true }
        var isReader = false
        if case .reader = screen { isReader = true }

        // Dismiss keyboard when leaving search
        var wasSearch = false
        if case .search = previousScreen { wasSearch = true }
        var isSearch = false
        if case .search = screen { isSearch = true }
        if isSearch && !wasSearch {
            // When the user returns from a reader that was entered via search,
            // preserve the original `screenBeforeSearch` anchor (typically `.books`
            // or `.verses(...)`) so the next back tap from `.search` returns to
            // the original starting point, not to a reader screen we just left.
            if !(wasReader && enteredReaderFromSearch) {
                screenBeforeSearch = previousScreen
            }
        }
        if wasSearch && !isSearch {
            searchField.resignFirstResponder()
        }

        // Hide select button unless entering reader
        if !isReader {
            selectButton.isHidden = true
        }

        // Update header
        switch screen {
        case .books:
            subtitleLabel.text = "Select a book or enter reference"
            subtitleLabel.textColor = UIColor(white: 1, alpha: 0.4)
            let xConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            backButton.setImage(UIImage(systemName: "xmark", withConfiguration: xConfig), for: .normal)
            showSearchField(true)
            searchIcon.isHidden = false
            updateSearchIcon(hasText: false)  // show magnifying glass

        case .chapters(let book):
            subtitleLabel.text = book.name
            subtitleLabel.textColor = .white
            let chevConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: chevConfig), for: .normal)
            showSearchField(true)

        case .verses(let book, let chapter):
            subtitleLabel.text = "\(book.name) \(chapter)"
            subtitleLabel.textColor = .white
            let chevConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: chevConfig), for: .normal)
            showSearchField(true)
            // Fetch actual verse count for this chapter
            Task {
                if let verses = await BibleCacheManager.shared.getChapterVerses(
                    bookNumber: book.id, chapter: chapter
                ) {
                    await MainActor.run {
                        self.versesGridCount = verses.count
                        self.collectionView.reloadData()
                    }
                }
            }

        case .reader(let book, let chapter, let verse):
            subtitleLabel.text = "Highlight passage"
            subtitleLabel.textColor = UIColor(white: 1, alpha: 0.4)
            let chevConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: chevConfig), for: .normal)
            showSearchField(false)
            searchLabel.text = "\(book.name) \(chapter):\(verse)"
            searchIcon.isHidden = false
            selectButton.isHidden = (onPassageConfirmed == nil)
            selectButton.isEnabled = false
            loadReaderContent(book: book, chapter: chapter, scrollToVerse: verse)

        case .search:
            subtitleLabel.text = "Search"
            subtitleLabel.textColor = .white
            let chevConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: chevConfig), for: .normal)
            showSearchField(true)
            searchIcon.isHidden = searchField.text?.isEmpty ?? true
        }

        guard animated else {
            currentScreen = screen
            collectionView.isHidden = isReader || isSearch
            readerContainer.isHidden = !isReader
            searchResultsTable.isHidden = !isSearch
            if !isReader && !isSearch { collectionView.reloadData() }
            return
        }

        // Dissolve transition for reader/search ↔ grid
        if isReader || wasReader || isSearch || wasSearch {
            currentScreen = screen
            if isReader {
                readerContainer.alpha = 0
                readerContainer.isHidden = false
            }
            if isSearch {
                searchResultsTable.alpha = 0
                searchResultsTable.isHidden = false
            }
            UIView.animate(withDuration: 0.3) {
                self.collectionView.alpha = (isReader || isSearch) ? 0 : 1
                self.readerContainer.alpha = isReader ? 1 : 0
                self.searchResultsTable.alpha = isSearch ? 1 : 0
            } completion: { _ in
                self.collectionView.isHidden = isReader || isSearch
                self.readerContainer.isHidden = !isReader
                self.searchResultsTable.isHidden = !isSearch
                if !isReader && !isSearch {
                    self.collectionView.alpha = 1
                    self.collectionView.reloadData()
                }
            }
            return
        }

        // Slide transition for grid ↔ grid
        let snapshot = collectionView.snapshotView(afterScreenUpdates: false)
        if let snapshot {
            snapshot.frame = collectionView.frame
            containerView.insertSubview(snapshot, aboveSubview: collectionView)
        }

        currentScreen = screen
        let gridWidth = collectionView.bounds.width
        let incomingStart: CGFloat = direction == .forward ? gridWidth : -gridWidth
        let outgoingEnd: CGFloat = direction == .forward ? -gridWidth * 0.3 : gridWidth * 0.3

        collectionView.transform = CGAffineTransform(translationX: incomingStart, y: 0)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.collectionView.transform = .identity
            snapshot?.transform = CGAffineTransform(translationX: outgoingEnd, y: 0)
            snapshot?.alpha = 0
        } completion: { _ in
            snapshot?.removeFromSuperview()
        }
    }

    // MARK: - Search Bar Mode

    private func showSearchField(_ showField: Bool) {
        searchField.isHidden = !showField
        searchLabel.isHidden = showField
    }

    // MARK: - Reader Content

    private func loadReaderContent(book: BibleBookInfo, chapter: Int, scrollToVerse: Int) {
        Task {
            // Fetch verses from cache for the selected translation
            guard let verses = await BibleCacheManager.shared.getChapterVerses(
                bookNumber: book.id,
                chapter: chapter
            ) else {
                // Fallback: show error
                await MainActor.run {
                    let text = NSMutableAttributedString(
                        string: "Unable to load verses. Please try again.",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 16),
                            .foregroundColor: UIColor(white: 1, alpha: 0.5),
                        ]
                    )
                    readerTextView.attributedText = text
                    clearVerseCircles()
                }
                return
            }

            let sortedVerses = verses.sorted { $0.v < $1.v }

            await MainActor.run {
                loadedVerses = sortedVerses
                verseRanges.removeAll()

                let text = NSMutableAttributedString(attributedString: renderChapterText(book: book, chapter: chapter, verses: sortedVerses))

                // Build verseRanges by walking the rendered text
                // Each verse is one line: "cleanText\n"
                var offset = 0
                // Skip the heading line (first line ending with \n)
                if let headingEnd = text.string.firstIndex(of: "\n") {
                    offset = text.string.distance(from: text.string.startIndex, to: headingEnd) + 1
                }
                for verse in sortedVerses {
                    var cleanText = verse.t
                    cleanText = cleanText.replacingOccurrences(of: "\\n", with: " ")
                    cleanText = cleanText.replacingOccurrences(of: "\\r", with: " ")
                    cleanText = cleanText.replacingOccurrences(of: "\n", with: " ")
                    cleanText = cleanText.replacingOccurrences(of: "\r", with: " ")
                    cleanText = cleanText.replacingOccurrences(of: "¶", with: "")
                    while cleanText.contains("  ") {
                        cleanText = cleanText.replacingOccurrences(of: "  ", with: " ")
                    }
                    cleanText = cleanText.trimmingCharacters(in: .whitespaces)
                    let len = cleanText.count + 1 // +1 for \n
                    verseRanges.append((verse: verse.v, range: NSRange(location: offset, length: len)))
                    offset += len
                }

                readerTextView.attributedText = text
                readerTextView.contentOffset = .zero

                // Pre-render adjacent chapters for swipe preview
                preloadAdjacentChapters(book: book, chapter: chapter)

                // Build verse circles after text is laid out
                DispatchQueue.main.async { [weak self] in
                    self?.layoutVerseCircles()

                    // Scroll to target verse (skip for verse 1 — stay at top showing chapter heading)
                    if scrollToVerse > 1, let self, let entry = self.verseRanges.first(where: { $0.verse == scrollToVerse }) {
                        let glyphRange = self.readerTextView.layoutManager.glyphRange(forCharacterRange: entry.range, actualCharacterRange: nil)
                        let rect = self.readerTextView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.readerTextView.textContainer)
                        let offsetY = max(0, rect.minY + self.readerTextView.textContainerInset.top - 20)
                        self.readerTextView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
                        self.syncCircleScroll()
                    }
                }
            }
        }
    }

    /// Renders chapter text as an NSAttributedString (shared by main reader and swipe preview).
    private func renderChapterText(book: BibleBookInfo, chapter: Int, verses: [VerseCompact]) -> NSAttributedString {
        let sortedVerses = verses.sorted { $0.v < $1.v }
        let text = NSMutableAttributedString()

        // Chapter heading
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.alignment = .center
        headingStyle.paragraphSpacingBefore = 8
        headingStyle.paragraphSpacing = 24
        text.append(NSAttributedString(
            string: "\(book.name) \(chapter)\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: headingStyle,
            ]
        ))

        let verseStyle = NSMutableParagraphStyle()
        verseStyle.lineSpacing = 6
        verseStyle.paragraphSpacing = 8

        let usedVerseKey = "\(book.id)-\(chapter)"
        let usedInThisChapter = usedVerses[usedVerseKey] ?? []
        let usedHighlightColor = brandPurple.withAlphaComponent(0.2)

        for verse in sortedVerses {
            var cleanText = verse.t
            cleanText = cleanText.replacingOccurrences(of: "\\n", with: " ")
            cleanText = cleanText.replacingOccurrences(of: "\\r", with: " ")
            cleanText = cleanText.replacingOccurrences(of: "\n", with: " ")
            cleanText = cleanText.replacingOccurrences(of: "\r", with: " ")
            cleanText = cleanText.replacingOccurrences(of: "¶", with: "")
            while cleanText.contains("  ") {
                cleanText = cleanText.replacingOccurrences(of: "  ", with: " ")
            }
            cleanText = cleanText.trimmingCharacters(in: .whitespaces)

            var bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.white,
                .paragraphStyle: verseStyle,
            ]
            if usedInThisChapter.contains(verse.v) {
                bodyAttrs[.backgroundColor] = usedHighlightColor
            }
            text.append(NSAttributedString(string: "\(cleanText)\n", attributes: bodyAttrs))
        }

        return text
    }

    /// Pre-renders adjacent chapters so they're ready for swipe preview.
    private func preloadAdjacentChapters(book: BibleBookInfo, chapter: Int) {
        // Next chapter
        if let (nextBook, nextChapter) = adjacentChapter(from: book, chapter: chapter, direction: .forward) {
            Task {
                if let verses = await BibleCacheManager.shared.getChapterVerses(
                    bookNumber: nextBook.id, chapter: nextChapter
                ) {
                    let rendered = renderChapterText(book: nextBook, chapter: nextChapter, verses: verses)
                    await MainActor.run { nextChapterRendered = rendered }
                }
            }
        } else {
            nextChapterRendered = nil
        }

        // Previous chapter
        if let (prevBook, prevChapter) = adjacentChapter(from: book, chapter: chapter, direction: .backward) {
            Task {
                if let verses = await BibleCacheManager.shared.getChapterVerses(
                    bookNumber: prevBook.id, chapter: prevChapter
                ) {
                    let rendered = renderChapterText(book: prevBook, chapter: prevChapter, verses: verses)
                    await MainActor.run { prevChapterRendered = rendered }
                }
            }
        } else {
            prevChapterRendered = nil
        }
    }

    // MARK: - Verse Circles

    private func clearVerseCircles() {
        verseCircleContainer.subviews.forEach { $0.removeFromSuperview() }
        verseCircleViews.removeAll()
    }

    private func layoutVerseCircles() {
        clearVerseCircles()

        let textView = readerTextView
        let layoutManager = textView.layoutManager
        let inset = textView.textContainerInset

        // Used verses for highlighting
        var usedInThisChapter = Set<Int>()
        if case .reader(let book, let chapter, _) = currentScreen {
            let key = "\(book.id)-\(chapter)"
            usedInThisChapter = usedVerses[key] ?? []
        }

        for entry in verseRanges {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: entry.range, actualCharacterRange: nil)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)

            // Position circle at the first line of this verse
            let circleY = lineRect.minY + inset.top
            let circleX: CGFloat = 16  // left margin

            let circle = UIView(frame: CGRect(x: circleX, y: circleY, width: 24, height: 24))
            circle.layer.cornerRadius = 12

            let isUsed = usedInThisChapter.contains(entry.verse)
            circle.backgroundColor = isUsed ? brandPurple.withAlphaComponent(0.3) : UIColor(white: 1, alpha: 0.1)

            let label = UILabel()
            label.text = "\(entry.verse)"
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = UIColor(white: 1, alpha: 0.6)
            label.textAlignment = .center
            label.frame = circle.bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            circle.addSubview(label)

            // Tap gesture
            circle.tag = entry.verse
            circle.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(verseCircleTapped(_:)))
            circle.addGestureRecognizer(tap)

            verseCircleContainer.addSubview(circle)
            verseCircleViews[entry.verse] = circle
        }

        // Size the container to match text content
        let contentHeight = textView.contentSize.height
        verseCircleContainer.frame = CGRect(
            x: 0, y: 0,
            width: 48,
            height: contentHeight
        )
    }

    @objc private func verseCircleTapped(_ gesture: UITapGestureRecognizer) {
        guard let circle = gesture.view else { return }
        let verseNum = circle.tag

        // Current selection expressed as a contiguous verse range.
        let currentSelection = versesOverlapping(readerTextView.selectedRange)
        let currentMin = currentSelection.first
        let currentMax = currentSelection.last

        // Tapping a verse circle inside the current selection clears it.
        if let minV = currentMin, let maxV = currentMax,
           verseNum >= minV && verseNum <= maxV {
            readerTextView.selectedRange = NSRange(location: 0, length: 0)
            if readerTextView.isFirstResponder {
                readerTextView.resignFirstResponder()
            }
            return
        }

        // No current selection → select just the tapped verse.
        // Existing selection → extend the range to include the tapped verse
        // and every verse between it and the existing range.
        let newMin = min(currentMin ?? verseNum, verseNum)
        let newMax = max(currentMax ?? verseNum, verseNum)

        guard let startEntry = verseRanges.first(where: { $0.verse == newMin }),
              let endEntry = verseRanges.first(where: { $0.verse == newMax }) else { return }

        let loc = startEntry.range.location
        let len = (endEntry.range.location + endEntry.range.length) - loc

        if !readerTextView.isFirstResponder {
            readerTextView.becomeFirstResponder()
        }
        readerTextView.selectedRange = NSRange(location: loc, length: len)
    }

    /// Tap on text body:
    /// - No selection: select the tapped verse
    /// - Tap inside selection: clear the selection
    /// - Tap outside selection: clear the selection
    @objc private func readerTextTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: readerTextView)
        let layoutManager = readerTextView.layoutManager
        let textContainer = readerTextView.textContainer
        let textOffset = CGPoint(
            x: point.x - readerTextView.textContainerInset.left,
            y: point.y - readerTextView.textContainerInset.top
        )
        let charIndex = layoutManager.characterIndex(
            for: textOffset, in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        // If there's an active selection, any tap on text clears it
        if readerTextView.selectedRange.length > 0 {
            readerTextView.selectedRange = NSRange(location: 0, length: 0)
            if readerTextView.isFirstResponder {
                readerTextView.resignFirstResponder()
            }
            return
        }

        // No selection — find the verse containing this character index and select it
        guard let entry = verseRanges.first(where: {
            charIndex >= $0.range.location &&
            charIndex < $0.range.location + $0.range.length
        }) else { return }

        if !readerTextView.isFirstResponder {
            readerTextView.becomeFirstResponder()
        }
        readerTextView.selectedRange = entry.range
    }

    /// Sync verse circle highlights based on which verses overlap the current text selection.
    private func updateVerseCircleHighlights() {
        let sel = readerTextView.selectedRange
        var usedInThisChapter = Set<Int>()
        if case .reader(let book, let chapter, _) = currentScreen {
            let key = "\(book.id)-\(chapter)"
            usedInThisChapter = usedVerses[key] ?? []
        }

        for entry in verseRanges {
            guard let circle = verseCircleViews[entry.verse] else { continue }
            let label = circle.subviews.compactMap { $0 as? UILabel }.first
            let isUsed = usedInThisChapter.contains(entry.verse)

            // Check if this verse overlaps the current selection
            let overlapStart = max(sel.location, entry.range.location)
            let overlapEnd = min(sel.location + sel.length, entry.range.location + entry.range.length)
            let isSelected = sel.length > 0 && overlapStart < overlapEnd

            if isSelected {
                circle.backgroundColor = brandPurple
                label?.textColor = .white
            } else if isUsed {
                circle.backgroundColor = brandPurple.withAlphaComponent(0.3)
                label?.textColor = UIColor(white: 1, alpha: 0.6)
            } else {
                circle.backgroundColor = UIColor(white: 1, alpha: 0.1)
                label?.textColor = UIColor(white: 1, alpha: 0.6)
            }
        }
    }

    /// Keep verse circles in sync with text view scroll position.
    private func syncCircleScroll() {
        let offsetY = readerTextView.contentOffset.y
        verseCircleContainer.frame.origin.y = -offsetY
    }

    // MARK: - Search

    private func performSearch(query: String) {
        searchTask?.cancel()

        // Navigate to search screen if not already there
        if case .search = currentScreen {} else {
            navigateTo(.search)
        }

        isSearchLoading = true
        searchResultsTable.reloadData()

        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            do {
                let result = try await BibleSearchService.shared.smartSearch(query: query)
                let items = BibleSearchService.shared.toSearchResultItems(result)
                let books = BibleSearchService.shared.toMatchedBooks(result)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.searchResults = items
                    self.matchedBooks = books
                    self.isSearchLoading = false
                    self.searchResultsTable.reloadData()
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("Search error: \(error)")
                await MainActor.run {
                    self.searchResults = []
                    self.matchedBooks = []
                    self.isSearchLoading = false
                    self.searchResultsTable.reloadData()
                }
            }
        }
    }

    private func loadRecentSearches() {
        isLoadingRecents = true
        searchResultsTable.reloadData()

        Task {
            do {
                let recents = try await BibleSearchService.shared.getRecentSearches()
                await MainActor.run {
                    self.recentSearches = recents
                    self.isLoadingRecents = false
                    self.searchResultsTable.reloadData()
                }
            } catch {
                print("Failed to load recent searches: \(error)")
                await MainActor.run {
                    self.recentSearches = []
                    self.isLoadingRecents = false
                    self.searchResultsTable.reloadData()
                }
            }
        }
    }

    /// Whether to show recent searches (no active query in search mode)
    private var showingRecents: Bool {
        guard case .search = currentScreen else { return false }
        return searchResults.isEmpty && matchedBooks.isEmpty && !isSearchLoading && (searchField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - UITableViewDataSource (Search Results)

    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearchLoading || isLoadingRecents || showingRecents { return 1 }
        // Section 0: matched books, Section 1: verse results
        let hasBooks = !matchedBooks.isEmpty
        let hasVerses = !searchResults.isEmpty
        if !hasBooks && !hasVerses { return 1 }  // empty state
        return (hasBooks ? 1 : 0) + (hasVerses ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearchLoading || isLoadingRecents { return 1 }
        if showingRecents { return max(recentSearches.count, 1) }
        if matchedBooks.isEmpty && searchResults.isEmpty { return 1 }  // empty state

        // With grouped results: section 0 = books (if any), next section = verses
        if !matchedBooks.isEmpty && section == 0 { return matchedBooks.count }
        return searchResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        // Loading spinner
        if isSearchLoading || isLoadingRecents {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = UIColor(white: 1, alpha: 0.5)
            spinner.startAnimating()
            spinner.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                spinner.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 40),
                spinner.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -40),
            ])
            return cell
        }

        // Recent searches (no query entered)
        if showingRecents {
            if recentSearches.isEmpty {
                return makeMessageCell(cell, text: "Type to search the Bible")
            }
            let recent = recentSearches[indexPath.row]
            let recentView = makeRecentSearchCell(query: recent.query)
            recentView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(recentView)
            NSLayoutConstraint.activate([
                recentView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                recentView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                recentView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                recentView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            ])
            return cell
        }

        // No results
        if matchedBooks.isEmpty && searchResults.isEmpty {
            return makeMessageCell(cell, text: "No results found")
        }

        // Matched book row (section 0 when books exist)
        if !matchedBooks.isEmpty && indexPath.section == 0 {
            let book = matchedBooks[indexPath.row]
            let bookView = makeMatchedBookCell(book: book)
            bookView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(bookView)
            NSLayoutConstraint.activate([
                bookView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                bookView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                bookView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                bookView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            ])
            return cell
        }

        // Search result card
        let result = searchResults[indexPath.row]
        let cardView = CardBibleSearchResult(reference: result.reference, text: result.text) { [weak self] in
            guard let self, let bookInfo = bibleBooks.first(where: { $0.id == result.bookNumber }) else { return }
            // Navigate to the reader with the tapped verse highlighted, mirroring the
            // verses-grid tap behavior. Notify the parent (informational only) and
            // keep the overlay open so the user can read / highlight the passage.
            // Mark that we entered the reader via search so the back button returns
            // to the search results, not to a verses grid the user never opened.
            self.enteredReaderFromSearch = true
            self.navigateTo(.reader(bookInfo, result.chapter, result.verse))
            self.onVerseSelected?(bookInfo, result.chapter, result.verse)
        }
        let hostingController = UIHostingController(rootView: cardView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 1),
            hostingController.view.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -1),
            hostingController.view.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            hostingController.view.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
        ])

        return cell
    }

    private func makeMessageCell(_ cell: UITableViewCell, text: String) -> UITableViewCell {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15)
        label.textColor = UIColor(white: 1, alpha: 0.5)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 40),
            label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -40),
        ])
        return cell
    }

    private func makeRecentSearchCell(query: String) -> UIView {
        let container = UIView()

        let icon = UIImageView(image: UIImage(systemName: "clock.arrow.circlepath", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)))
        icon.tintColor = UIColor(white: 1, alpha: 0.5)
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        let label = UILabel()
        label.text = query
        label.font = .systemFont(ofSize: 15)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 44),
        ])

        return container
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isSearchLoading, !isLoadingRecents, !showingRecents else { return nil }
        guard !matchedBooks.isEmpty || !searchResults.isEmpty else { return nil }

        let title: String
        if !matchedBooks.isEmpty && section == 0 {
            title = "Books"
        } else {
            title = "Verses"
        }

        let header = UIView()
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor(white: 1, alpha: 0.4)
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -4),
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard !isSearchLoading, !isLoadingRecents, !showingRecents else { return 0 }
        guard !matchedBooks.isEmpty || !searchResults.isEmpty else { return 0 }
        return 28
    }

    private func makeMatchedBookCell(book: MatchedBook) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(white: 1, alpha: 0.05)
        container.layer.cornerRadius = 4

        let icon = UIImageView(image: UIImage(systemName: "book.closed", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)))
        icon.tintColor = .white
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        let nameLabel = UILabel()
        nameLabel.text = book.bookName
        nameLabel.font = .systemFont(ofSize: 12, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let detailLabel = UILabel()
        detailLabel.text = "\(book.chapters) chapters · \(book.testament == "OT" ? "Old Testament" : "New Testament")"
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = UIColor(white: 1, alpha: 0.7)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            detailLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            detailLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor),
        ])

        return container
    }

    // MARK: - UITableViewDelegate (Search Results)

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isSearchLoading, !isLoadingRecents else { return }

        // Tapping a recent search fills the search field and performs the search
        if showingRecents {
            guard indexPath.row < recentSearches.count else { return }
            let query = recentSearches[indexPath.row].query
            searchField.text = query
            searchIcon.isHidden = false
            updateSearchIcon(hasText: true)
            setNeedsLayout()
            performSearch(query: query)
            return
        }

        // Tapping a matched book navigates to that book's chapters
        if !matchedBooks.isEmpty && indexPath.section == 0 {
            guard indexPath.row < matchedBooks.count else { return }
            let matched = matchedBooks[indexPath.row]
            guard let bookInfo = bibleBooks.first(where: { $0.id == matched.bookNumber }) else { return }
            // Clear search state and navigate to chapters for this book
            searchTask?.cancel()
            searchResults = []
            matchedBooks = []
            searchField.text = ""
            searchIcon.isHidden = false
            updateSearchIcon(hasText: false)
            navigateTo(.chapters(bookInfo), direction: .forward)
            return
        }

        // Verse results — handled by the CardBibleSearchResult onTap closure
        // (UIHostingController intercepts the tap via the SwiftUI Button)
    }

    // MARK: - Actions

    private var versionDropdown: BibleVersionDropdown?

    @objc private func versionTapped() {
        // Toggle dropdown
        if let existing = versionDropdown {
            existing.dismiss()
            versionDropdown = nil
            return
        }

        // Read translations from app state, popular ones first
        let popularCodes: [String] = ["KJV", "NIV", "ESV", "NASB", "NLT", "NKJV", "CSB", "BSB", "WEB", "ASV"]
        let allVersions = AppState.shared.bibleTranslations
        let versions = allVersions.sorted { a, b in
            let aIdx = popularCodes.firstIndex(of: a.code.uppercased()) ?? Int.max
            let bIdx = popularCodes.firstIndex(of: b.code.uppercased()) ?? Int.max
            if aIdx != bIdx { return aIdx < bIdx }
            return a.name < b.name
        }

        // Anchor below the version button, aligned left
        let buttonFrame = versionButton.convert(versionButton.bounds, to: self)
        let dropdown = BibleVersionDropdown(
            anchorFrame: buttonFrame,
            selectedVersionId: selectedVersionId,
            versions: versions
        ) { [weak self] version in
            self?.selectedVersionId = version.id
            self?.updateVersion(version.code)
            self?.versionDropdown?.dismiss()
            self?.versionDropdown = nil
        }
        addSubview(dropdown)
        dropdown.frame = bounds
        bringSubviewToFront(dropdown)
        dropdown.show()
        versionDropdown = dropdown
    }

    @objc private func bookListTapped() {
        navigateTo(.books, direction: .backward)
    }

    @objc private func searchTapped() {
        let hasText = !(searchField.text ?? "").isEmpty

        if hasText {
            // X button: clear the query but stay in search mode with the
            // input focused and the default (recent searches) state restored.
            searchTask?.cancel()
            // Reset isSearchLoading explicitly — cancelling the task only triggers
            // the early `guard !Task.isCancelled` exit, which never reaches the
            // MainActor block that clears isSearchLoading.
            isSearchLoading = false
            searchField.text = ""
            searchResults = []
            matchedBooks = []
            updateSearchIcon(hasText: false)
            setNeedsLayout()

            // Make sure we're on the search screen so the recent searches list
            // becomes visible after we reload it.
            if case .search = currentScreen {
                searchResultsTable.reloadData()
            } else {
                navigateTo(.search)
            }

            // Refocus the input and refresh recent searches as the default state.
            searchField.becomeFirstResponder()
            loadRecentSearches()
        } else {
            // Magnifying glass: enter search mode
            navigateTo(.search)
            searchField.becomeFirstResponder()
            loadRecentSearches()
        }
    }

    /// Animate the modal up from the bottom of the screen
    func presentFromBottom() {
        containerView.frame.origin.y = bounds.height
        scrimView.alpha = 0

        let safeTop = safeAreaInsets.top
        let targetY = safeTop + 10

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.92,
                       initialSpringVelocity: 0, options: []) {
            self.containerView.frame.origin.y = targetY
            self.scrimView.alpha = 1
        }
    }

    /// Animate dismiss (slide down + fade scrim) and remove from view hierarchy
    func animateDismissAndRemove() {
        searchField.resignFirstResponder()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.containerView.frame.origin.y = self.bounds.height
            self.scrimView.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            self.onDismiss()
        }
    }

    @objc private func backTapped() {
        switch currentScreen {
        case .books:
            animateDismissAndRemove()
        case .chapters:
            navigateTo(.books, direction: .backward)
        case .verses(let book, _):
            navigateTo(.chapters(book), direction: .backward)
        case .reader(let book, let chapter, _):
            // If the user got into the reader by tapping a search result, return
            // to the search screen so the results stay visible. Otherwise return
            // to the verses grid for the current chapter.
            if enteredReaderFromSearch {
                enteredReaderFromSearch = false
                navigateTo(.search, direction: .backward)
            } else {
                navigateTo(.verses(book, chapter), direction: .backward)
            }
        case .search:
            searchTask?.cancel()
            searchResults = []
            matchedBooks = []
            searchField.text = ""
            searchIcon.isHidden = false
            updateSearchIcon(hasText: false)
            navigateTo(screenBeforeSearch, direction: .backward)
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        // When search field is focused, enter search mode and load recent searches
        if case .search = currentScreen { return }  // already in search
        navigateTo(.search)
        loadRecentSearches()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Just dismiss the keyboard. The debounced search fired from
        // textField(_:shouldChangeCharactersIn:) already produced the
        // results on screen — re-running performSearch here would
        // cancel any in-flight task, flip isSearchLoading back to true,
        // reloadData() (which flashes the spinner), and re-query the
        // same term. That's the visible "reload" the user sees when
        // dismissing the keyboard.
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
        let hasText = !newText.isEmpty
        searchIcon.isHidden = !hasText
        updateSearchIcon(hasText: hasText)
        setNeedsLayout()

        // Debounced search as user types
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            performSearch(query: trimmed)
        } else if case .search = currentScreen {
            // User cleared the query (manually backspaced or selected-all + delete).
            // Mirror the X-button behavior: stay in search mode, keep the input
            // focused, and reset to the default recent-searches state.
            // The state mutations are deferred to the next runloop turn so UIKit
            // gets a chance to apply the deletion before we touch the table.
            searchTask?.cancel()
            // Reset isSearchLoading explicitly — cancelling the task only triggers
            // the early `guard !Task.isCancelled` exit, which never reaches the
            // MainActor block that clears isSearchLoading. Without this, the
            // spinner cell renders forever after backspacing the final character.
            isSearchLoading = false
            searchResults = []
            matchedBooks = []
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.searchResultsTable.reloadData()
                if !self.searchField.isFirstResponder {
                    self.searchField.becomeFirstResponder()
                }
                self.loadRecentSearches()
            }
        }

        return true
    }

    /// Switch search icon between magnifyingglass (empty) and xmark (has text)
    private func updateSearchIcon(hasText: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 14)
        let iconName = hasText ? "xmark" : "magnifyingglass"
        searchIcon.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }

    // MARK: - UITextViewDelegate (reader text selection)

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard case .reader(let book, let chapter, _) = currentScreen else { return }

        // Snap selection to word boundaries so partial words are never highlighted.
        if textView.selectedRange.length > 0, let text = textView.text {
            let nsText = text as NSString
            let sel = textView.selectedRange

            let isWordChar: (Int) -> Bool = { pos in
                guard pos >= 0 && pos < nsText.length else { return false }
                guard let scalar = Unicode.Scalar(nsText.character(at: pos)) else { return false }
                return !CharacterSet.whitespacesAndNewlines.contains(scalar)
                    && !CharacterSet.punctuationCharacters.contains(scalar)
            }

            // Expand start to beginning of word
            var wordStart = sel.location
            while wordStart > 0 && isWordChar(wordStart - 1) {
                wordStart -= 1
            }

            // Expand end to end of word — but only if the selection currently
            // ends mid-word. If it already terminates at a non-word character
            // (the "\n" that ends each verse falls into this bucket), leave
            // wordEnd alone. Without this guard, tapping a verse circle
            // selects the whole verse + trailing newline, and the snap walks
            // forward into the first word of the *next* verse.
            var wordEnd = sel.location + sel.length
            if wordEnd > 0 && isWordChar(wordEnd - 1) {
                while wordEnd < nsText.length && isWordChar(wordEnd) {
                    wordEnd += 1
                }
            }

            // Ensure we haven't collapsed to nothing
            if wordStart >= wordEnd {
                wordStart = sel.location
                wordEnd = sel.location + sel.length
            }

            let snapped = NSRange(location: wordStart, length: wordEnd - wordStart)
            if snapped != sel {
                textView.selectedRange = snapped
                return  // Will re-enter with snapped range
            }
        }

        let hasSelection = textView.selectedRange.length > 0
        selectButton.isEnabled = hasSelection

        // When the selection is cleared (e.g. via the system "×" dismiss button),
        // resign first responder so a subsequent tap doesn't immediately re-create
        // the selection. Without this, the text view stays in selection mode and
        // any tap re-selects at that position — making the highlight appear to
        // "come back" even though the user dismissed it.
        if !hasSelection && textView.isFirstResponder {
            textView.resignFirstResponder()
        }

        // Update verse circle highlights immediately and again after a brief
        // delay — the system dismiss can clear the tint asynchronously,
        // leaving circles stale if we only check once.
        updateVerseCircleHighlights()
        if !hasSelection {
            DispatchQueue.main.async { [weak self] in
                self?.updateVerseCircleHighlights()
            }
        }

        if hasSelection {
            // Find which verses overlap the selection
            let sel = textView.selectedRange
            let overlapping = versesOverlapping(sel)
            if let vs = overlapping.first, let ve = overlapping.last {
                if ve > vs {
                    subtitleLabel.text = "\(book.name) \(chapter):\(vs)-\(ve)"
                } else {
                    subtitleLabel.text = "\(book.name) \(chapter):\(vs)"
                }
                subtitleLabel.textColor = .white
            }
        } else {
            subtitleLabel.text = "Highlight passage"
            subtitleLabel.textColor = UIColor(white: 1, alpha: 0.4)
        }
    }

    /// Returns sorted verse numbers that overlap the given character range.
    private func versesOverlapping(_ range: NSRange) -> [Int] {
        var result: [Int] = []
        for entry in verseRanges {
            let overlapStart = max(range.location, entry.range.location)
            let overlapEnd = min(range.location + range.length, entry.range.location + entry.range.length)
            if overlapStart < overlapEnd {
                result.append(entry.verse)
            }
        }
        return result.sorted()
    }

    // MARK: - UIScrollViewDelegate (sync verse circles with text scroll)

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === readerTextView {
            syncCircleScroll()
            updateTopVerseLabel()
        }
    }

    /// Updates the search label to show the verse currently at the top of the visible reader area.
    private func updateTopVerseLabel() {
        guard case .reader(let book, let chapter, _) = currentScreen else { return }
        guard !verseRanges.isEmpty else { return }

        let topOffset = readerTextView.contentOffset.y + readerTextView.textContainerInset.top
        var topVerse = verseRanges[0].verse

        for entry in verseRanges {
            let glyphRange = readerTextView.layoutManager.glyphRange(
                forCharacterRange: entry.range, actualCharacterRange: nil
            )
            let rect = readerTextView.layoutManager.boundingRect(
                forGlyphRange: glyphRange, in: readerTextView.textContainer
            )
            if rect.minY + readerTextView.textContainerInset.top <= topOffset + 4 {
                topVerse = entry.verse
            } else {
                break
            }
        }

        searchLabel.text = "\(book.name) \(chapter):\(topVerse)"
    }

    @objc private func selectTapped() {
        guard case .reader(let book, let chapter, _) = currentScreen else {
            NSLog("📖 selectTapped: not in reader screen")
            return
        }
        let range = readerTextView.selectedRange
        guard range.length > 0 else {
            NSLog("📖 selectTapped: no selection")
            return
        }

        let overlapping = versesOverlapping(range)
        guard let verseStart = overlapping.first, let verseEnd = overlapping.last else {
            NSLog("📖 selectTapped: no verses in selection")
            return
        }

        // Build selected text with verse numbers prepended
        let selectedText = loadedVerses
            .filter { overlapping.contains($0.v) }
            .sorted { $0.v < $1.v }
            .map { verse -> String in
                var text = verse.t
                text = text.replacingOccurrences(of: "\\n", with: " ")
                text = text.replacingOccurrences(of: "\\r", with: " ")
                text = text.replacingOccurrences(of: "\n", with: " ")
                text = text.replacingOccurrences(of: "\r", with: " ")
                while text.contains("  ") {
                    text = text.replacingOccurrences(of: "  ", with: " ")
                }
                return "\(verse.v). \(text.trimmingCharacters(in: .whitespaces))"
            }
            .joined(separator: "\n")

        NSLog("📖 selectTapped: verses \(verseStart)-\(verseEnd)")

        animateDismissAndRemove()
        onPassageConfirmed?(book, chapter, verseStart, verseEnd, selectedText)
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        switch currentScreen {
        case .books:
            return 2  // OT, NT
        case .chapters, .verses:
            return 1
        case .reader, .search:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch currentScreen {
        case .books:
            return section == 0 ? oldTestamentBooks.count : newTestamentBooks.count
        case .chapters(let book):
            return book.chapters
        case .verses(_, _):
            return versesGridCount
        case .reader, .search:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch currentScreen {
        case .books:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BookCell", for: indexPath) as! BookCell
            let book = indexPath.section == 0 ? oldTestamentBooks[indexPath.item] : newTestamentBooks[indexPath.item]
            let isUsed = usedBookNumbers.contains(book.id)
            cell.configure(with: book, isUsed: isUsed, brandPurple: brandPurple)
            return cell

        case .chapters(let book):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NumberCell", for: indexPath) as! NumberCell
            let chapter = indexPath.item + 1
            let isUsed = usedChapters[book.id]?.contains(chapter) ?? false
            cell.configure(number: chapter, backgroundColor: isUsed ? brandPurple : cellBg)
            return cell

        case .verses(let book, let chapter):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NumberCell", for: indexPath) as! NumberCell
            let verse = indexPath.item + 1
            let key = "\(book.id)-\(chapter)"
            let isUsed = usedVerses[key]?.contains(verse) ?? false
            cell.configure(number: verse, backgroundColor: isUsed ? brandPurple : cellBg)
            return cell

        case .reader, .search:
            return UICollectionViewCell()
        }
    }

    // Section header for spacing between OT and NT
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionSpacer", for: indexPath)
        return view
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        switch currentScreen {
        case .books:
            return section == 0 ? .zero : CGSize(width: collectionView.bounds.width, height: 2)
        default:
            return .zero
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset = collectionView.contentInset
        let availableWidth = collectionView.bounds.width - inset.left - inset.right
        let columns: CGFloat = 5
        let spacing: CGFloat = 2
        let totalSpacing = spacing * (columns - 1)
        let cellWidth = floor((availableWidth - totalSpacing) / columns)
        return CGSize(width: cellWidth, height: 44)
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch currentScreen {
        case .books:
            let book = indexPath.section == 0 ? oldTestamentBooks[indexPath.item] : newTestamentBooks[indexPath.item]
            navigateTo(.chapters(book))

        case .chapters(let book):
            let chapter = indexPath.item + 1
            navigateTo(.verses(book, chapter))

        case .verses(let book, let chapter):
            let verse = indexPath.item + 1
            // Reader was entered from the verses grid, so back should return there.
            enteredReaderFromSearch = false
            navigateTo(.reader(book, chapter, verse))
            onVerseSelected?(book, chapter, verse)

        case .reader, .search:
            break
        }
    }
}

// MARK: - BookCell (colored background with abbreviation)

private class BookCell: UICollectionViewCell {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(with book: BibleBookInfo, isUsed: Bool = false, brandPurple: UIColor? = nil) {
        label.text = book.abbreviation
        contentView.backgroundColor = isUsed ? (brandPurple ?? book.category.uiColor) : book.category.uiColor
    }
}

// MARK: - NumberCell (chapter/verse number)

private class NumberCell: UICollectionViewCell {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 15)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(number: Int, backgroundColor: UIColor) {
        label.text = "\(number)"
        contentView.backgroundColor = backgroundColor
    }
}

// MARK: - SectionSpacer (gap between OT and NT)

private class SectionSpacer: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - SwiftUI Preview

private class BibleReaderPreviewVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let overlay = BibleReaderOverlayView(
            overlayManager: OverlayManager(),
            onDismiss: {}
        )
        overlay.frame = view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)
    }
}

private struct BibleReaderPreviewBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> BibleReaderPreviewVC {
        BibleReaderPreviewVC()
    }
    func updateUIViewController(_ vc: BibleReaderPreviewVC, context: Context) {}
}

#Preview {
    BibleReaderPreviewBridge()
        .ignoresSafeArea()
}
