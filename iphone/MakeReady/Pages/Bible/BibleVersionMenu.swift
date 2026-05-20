//
//  BibleVersionMenu.swift
//  MakeReady
//
//  UIKit dropdown translation picker for the Bible reader.
//  Appears as a popover anchored below the version button.
//

import UIKit

// MARK: - Bible Version

struct BibleVersion: Identifiable, Equatable, Codable {
    let id: String           // API.Bible ID
    let code: String         // Abbreviation (e.g., "KJV", "NASB")
    let name: String         // Full display name
    let language: String?
    let description: String?
    let copyright: String?
}

struct BibleTranslationsResponse: Codable {
    let translations: [BibleVersion]?
    let error: String?
}

// MARK: - Known Translations (cached from API)

let knownBibleVersions: [BibleVersion] = [
    BibleVersion(id: "de4e12af7f28f599-02", code: "KJV",  name: "King James (Authorised) Version",           language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "01b29f4b342acc35-01", code: "ASV",  name: "American Standard Version",                  language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "9879dbb7cfe39e4d-04", code: "FBV",  name: "Free Bible Version",                        language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "65eec8e0b60e656b-01", code: "GNV",  name: "Geneva Bible",                               language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "55212e3cf4d04c49-01", code: "GNTD", name: "Good News Translation (US Version)",         language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "b32b9d1b64b4ef29-01", code: "LSV",  name: "Literal Standard Version",                   language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "c315fa9f71d4af3a-01", code: "WEB",  name: "World English Bible",                        language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "f72b840c855f362c-04", code: "WEBBE",name: "World English Bible, British Edition",       language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "7142879509583d59-04", code: "T4T",  name: "Translation for Translators",                language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "bba9f40f2062d3ca-01", code: "BSB",  name: "Berean Standard Bible",                      language: "eng", description: nil, copyright: nil),
]

// MARK: - Dropdown Overlay

final class BibleVersionDropdown: UIView, UITableViewDataSource, UITableViewDelegate {

    private let versions: [BibleVersion]
    private var selectedVersionId: String
    private let onVersionChanged: (BibleVersion) -> Void
    private let anchorFrame: CGRect

    private let scrim = UIView()
    private let menuContainer = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    private let brandPurple = UIColor(red: 0x6C/255, green: 0x47/255, blue: 0xFF/255, alpha: 1)
    private let menuBg = UIColor(red: 0x1E/255, green: 0x21/255, blue: 0x2D/255, alpha: 1)

    init(anchorFrame: CGRect, selectedVersionId: String, versions: [BibleVersion], onVersionChanged: @escaping (BibleVersion) -> Void) {
        self.anchorFrame = anchorFrame
        self.selectedVersionId = selectedVersionId
        self.versions = versions
        self.onVersionChanged = onVersionChanged
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Transparent scrim to catch taps outside
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        scrim.alpha = 0
        addSubview(scrim)
        let tap = UITapGestureRecognizer(target: self, action: #selector(scrimTapped))
        scrim.addGestureRecognizer(tap)

        // Menu container — shadow on this layer, clipping on sublayer
        menuContainer.backgroundColor = .clear
        menuContainer.layer.shadowColor = UIColor.black.cgColor
        menuContainer.layer.shadowOpacity = 0.5
        menuContainer.layer.shadowRadius = 20
        menuContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        menuContainer.clipsToBounds = false
        addSubview(menuContainer)

        // Inner view for corner radius clipping
        let innerClip = UIView()
        innerClip.backgroundColor = menuBg
        innerClip.layer.cornerRadius = 12
        innerClip.clipsToBounds = true
        innerClip.tag = 999
        menuContainer.addSubview(innerClip)

        // Table view
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor(white: 1, alpha: 0.1)
        tableView.separatorInset = .zero
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(VersionDropdownCell.self, forCellReuseIdentifier: "VersionDropdownCell")
        tableView.rowHeight = 48
        innerClip.addSubview(tableView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrim.frame = bounds

        let menuX: CGFloat = 16
        let menuY = anchorFrame.maxY + 6
        let menuWidth = bounds.width - 32
        let maxAvailableHeight = bounds.height - menuY - 16
        let contentHeight = min(CGFloat(versions.count) * 48, maxAvailableHeight)

        // With anchorPoint at (0,0), set position (not frame) to avoid offset
        menuContainer.bounds = CGRect(x: 0, y: 0, width: menuWidth, height: contentHeight)
        menuContainer.layer.position = CGPoint(x: menuX, y: menuY)
        menuContainer.viewWithTag(999)?.frame = menuContainer.bounds
        tableView.frame = menuContainer.bounds
    }

    // MARK: - Show / Dismiss

    func show() {
        // Anchor transforms to top-left so menu doesn't shift horizontally
        menuContainer.layer.anchorPoint = CGPoint(x: 0, y: 0)
        menuContainer.alpha = 0
        menuContainer.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).translatedBy(x: 0, y: -4)

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.scrim.alpha = 1
            self.menuContainer.alpha = 1
            self.menuContainer.transform = .identity
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseIn) {
            self.menuContainer.alpha = 0
            self.menuContainer.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).translatedBy(x: 0, y: -4)
            self.scrim.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    @objc private func scrimTapped() {
        dismiss()
        if let parent = superview as? BibleReaderOverlayView {
            parent.clearVersionDropdown()
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        versions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VersionDropdownCell", for: indexPath) as! VersionDropdownCell
        let version = versions[indexPath.row]
        cell.configure(version: version, isSelected: version.id == selectedVersionId, brandColor: brandPurple)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let version = versions[indexPath.row]
        selectedVersionId = version.id
        onVersionChanged(version)
    }
}

// MARK: - Version Dropdown Cell

private class VersionDropdownCell: UITableViewCell {

    private let radioView = UIView()
    private let checkmark = UIImageView()
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        radioView.layer.cornerRadius = 12
        radioView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(radioView)

        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        checkmark.image = UIImage(systemName: "checkmark", withConfiguration: config)
        checkmark.tintColor = .white
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        radioView.addSubview(checkmark)

        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            radioView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            radioView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            radioView.widthAnchor.constraint(equalToConstant: 24),
            radioView.heightAnchor.constraint(equalToConstant: 24),

            checkmark.centerXAnchor.constraint(equalTo: radioView.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: radioView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: radioView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(version: BibleVersion, isSelected: Bool, brandColor: UIColor) {
        nameLabel.text = version.name

        if isSelected {
            radioView.backgroundColor = brandColor
            radioView.layer.borderWidth = 0
            checkmark.isHidden = false
        } else {
            radioView.backgroundColor = .clear
            radioView.layer.borderWidth = 1
            radioView.layer.borderColor = UIColor(white: 1, alpha: 0.2).cgColor
            checkmark.isHidden = true
        }
    }
}
