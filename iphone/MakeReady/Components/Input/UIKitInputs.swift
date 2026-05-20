//
//  UIKitInputs.swift
//  MakeReady
//
//  UIKit input components matching the SwiftUI TextInput, MultilineTextInput,
//  and TagInput equivalents. Use these inside UIKit view hierarchies (overlays, UIView subclasses).
//

import UIKit
import SwiftUI

// MARK: - FloatingLabelTextField

/// UIKit text field with an animated floating label that moves up when focused or filled.
/// Matches the SwiftUI `TextInput(floatingLabel:)` variant.
final class FloatingLabelTextField: UIView, UITextFieldDelegate {

    var text: String {
        get { textField.text ?? "" }
        set {
            textField.text = newValue
            updateLabelPosition(animated: false)
        }
    }

    private let label: String
    private let floatingLabel = UILabel()
    private let textField = UITextField()

    private var labelTopConstraint: NSLayoutConstraint!
    private var isFloating = false

    init(label: String) {
        self.label = label
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(white: 1, alpha: 0.06)
        layer.cornerRadius = 12

        floatingLabel.text = label
        floatingLabel.font = .systemFont(ofSize: 15)
        floatingLabel.textColor = UIColor(white: 1, alpha: 0.4)
        floatingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(floatingLabel)

        textField.font = .systemFont(ofSize: 15)
        textField.textColor = .white
        textField.tintColor = UIColor(red: 0x6C/255, green: 0x47/255, blue: 0xFF/255, alpha: 1)
        textField.backgroundColor = .clear
        textField.delegate = self
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        labelTopConstraint = floatingLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56),

            labelTopConstraint,
            floatingLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            floatingLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            textField.heightAnchor.constraint(equalToConstant: 24),
        ])

        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        updateLabelPosition(animated: false)
    }

    @objc private func textChanged() {
        updateLabelPosition(animated: true)
    }

    private func updateLabelPosition(animated: Bool) {
        let shouldFloat = textField.isFirstResponder || !text.isEmpty
        guard shouldFloat != isFloating else { return }
        isFloating = shouldFloat

        labelTopConstraint.constant = shouldFloat ? 8 : 18
        floatingLabel.font = shouldFloat ? .systemFont(ofSize: 11, weight: .medium) : .systemFont(ofSize: 15)
        floatingLabel.textColor = shouldFloat
            ? UIColor(red: 0x6C/255, green: 0x47/255, blue: 0xFF/255, alpha: 1)
            : UIColor(white: 1, alpha: 0.4)

        if animated {
            UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
        }
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        updateLabelPosition(animated: true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateLabelPosition(animated: true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - FloatingLabelTextView

/// UIKit multiline text view with an animated floating label.
/// Matches the SwiftUI `MultilineTextInput` component.
final class FloatingLabelTextView: UIView, UITextViewDelegate {

    var text: String {
        get { textView.text ?? "" }
        set {
            textView.text = newValue
            updateLabelPosition(animated: false)
        }
    }

    private let label: String
    private let floatingLabel = UILabel()
    private let textView = UITextView()
    private var labelTopConstraint: NSLayoutConstraint!
    private var isFloating = false

    init(label: String) {
        self.label = label
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(white: 1, alpha: 0.06)
        layer.cornerRadius = 12

        floatingLabel.text = label
        floatingLabel.font = .systemFont(ofSize: 15)
        floatingLabel.textColor = UIColor(white: 1, alpha: 0.4)
        floatingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(floatingLabel)

        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .white
        textView.tintColor = UIColor(red: 0x6C/255, green: 0x47/255, blue: 0xFF/255, alpha: 1)
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        labelTopConstraint = floatingLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            labelTopConstraint,
            floatingLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            floatingLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])

        updateLabelPosition(animated: false)
    }

    private func updateLabelPosition(animated: Bool) {
        let shouldFloat = textView.isFirstResponder || !text.isEmpty
        guard shouldFloat != isFloating else { return }
        isFloating = shouldFloat

        labelTopConstraint.constant = shouldFloat ? 8 : 18
        floatingLabel.font = shouldFloat ? .systemFont(ofSize: 11, weight: .medium) : .systemFont(ofSize: 15)
        floatingLabel.textColor = shouldFloat
            ? UIColor(red: 0x6C/255, green: 0x47/255, blue: 0xFF/255, alpha: 1)
            : UIColor(white: 1, alpha: 0.4)

        if animated {
            UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        updateLabelPosition(animated: true)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        updateLabelPosition(animated: true)
    }

    func textViewDidChange(_ textView: UITextView) {
        invalidateIntrinsicContentSize()
    }
}

// MARK: - UIKitTagInput

/// Observable bridge so SwiftUI TagInput can read/write tags and trigger re-renders.
private class TagInputState: ObservableObject {
    @Published var tags: [String]
    let originalTags: Set<String>

    init(tags: [String]) {
        self.tags = tags
        self.originalTags = Set(tags)
    }
}

/// SwiftUI wrapper that observes the shared state object.
private struct TagInputBridge: View {
    @ObservedObject var state: TagInputState
    let placeholder: String

    var body: some View {
        TagInput(
            tags: $state.tags,
            placeholder: placeholder,
            originalTags: state.originalTags
        )
    }
}

/// UIKit wrapper around the SwiftUI `TagInput` component via UIHostingController.
/// Provides the exact same tag editing experience everywhere — purple pills with white "x"
/// for existing tags, muted pills for newly added (unsaved) tags.
final class UIKitTagInput: UIView {

    private let state: TagInputState
    private let placeholder: String
    private var hostingController: UIHostingController<TagInputBridge>?

    /// Current tags (read this when saving)
    var tags: [String] { state.tags }

    init(tags: [String], placeholder: String = "Add tag...") {
        self.state = TagInputState(tags: tags)
        self.placeholder = placeholder
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let bridge = TagInputBridge(state: state, placeholder: placeholder)
        let hostVC = UIHostingController(rootView: bridge)
        hostVC.view.backgroundColor = .clear
        hostVC.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostVC.view)
        self.hostingController = hostVC

        NSLayoutConstraint.activate([
            hostVC.view.topAnchor.constraint(equalTo: topAnchor),
            hostVC.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostVC.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostVC.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override var intrinsicContentSize: CGSize {
        hostingController?.view.intrinsicContentSize ?? CGSize(width: UIView.noIntrinsicMetric, height: 52)
    }
}
