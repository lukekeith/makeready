//
//  KeyboardToolbar.swift
//  MakeReady
//
//  Centralized keyboard dismiss button using UIKit inputAccessoryView.
//  Guarantees exactly ONE checkmark button on the keyboard regardless of
//  how many views are in the hierarchy. Works without NavigationStack.
//
//  - No changes: translucent white "x" button (dismiss)
//  - Value changed: purple checkmark button (confirm)
//
//  Call KeyboardToolbarInstaller.install() once at app launch.
//

import SwiftUI
import UIKit

// MARK: - Accessory View

/// Floating circle button above the keyboard, right-aligned.
/// Switches between dismiss (x) and confirm (checkmark) based on whether
/// the active text field's value has changed since it gained focus.
final class KeyboardDismissAccessoryView: UIView {
    static let shared = KeyboardDismissAccessoryView()

    private let button = UIButton(type: .custom)
    private var initialValue: String?
    private var hasChanges = false
    private var observations: [Any] = []

    private let purpleColor = UIColor(red: 108/255, green: 71/255, blue: 1, alpha: 1)
    private let dismissBackground = UIColor.white.withAlphaComponent(0.12)

    private init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 48))
        autoresizingMask = .flexibleWidth
        backgroundColor = .clear

        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(dismissKeyboard), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        applyDismissStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    // Allow touches to pass through to the keyboard for keys not covered by the button
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    // MARK: - Track Field Changes

    func trackField(_ field: UITextField) {
        clearObservations()
        initialValue = field.text ?? ""
        hasChanges = false
        applyDismissStyle()

        let token = NotificationCenter.default.addObserver(
            forName: UITextField.textDidChangeNotification,
            object: field,
            queue: .main
        ) { [weak self] notification in
            guard let self, let tf = notification.object as? UITextField else { return }
            let changed = (tf.text ?? "") != self.initialValue
            if changed != self.hasChanges {
                self.hasChanges = changed
                self.updateStyle()
            }
        }
        observations.append(token)
    }

    func trackTextView(_ textView: UITextView) {
        clearObservations()
        initialValue = textView.text ?? ""
        hasChanges = false
        applyDismissStyle()

        let token = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] notification in
            guard let self, let tv = notification.object as? UITextView else { return }
            let changed = (tv.text ?? "") != self.initialValue
            if changed != self.hasChanges {
                self.hasChanges = changed
                self.updateStyle()
            }
        }
        observations.append(token)
    }

    private func clearObservations() {
        for token in observations {
            NotificationCenter.default.removeObserver(token)
        }
        observations.removeAll()
    }

    // MARK: - Styling

    private func updateStyle() {
        UIView.animate(withDuration: 0.15) {
            if self.hasChanges {
                self.applyConfirmStyle()
            } else {
                self.applyDismissStyle()
            }
        }
    }

    private func applyDismissStyle() {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = .white.withAlphaComponent(0.7)
        button.backgroundColor = dismissBackground
    }

    private func applyConfirmStyle() {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        button.setImage(UIImage(systemName: "checkmark", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = purpleColor
    }

    @objc private func dismissKeyboard() {
        // If the active field has a delegate that handles return (e.g. tag input),
        // trigger it before dismissing so pending input gets committed
        if let activeField = findActiveTextField() {
            if let delegate = activeField.delegate {
                _ = delegate.textFieldShouldReturn?(activeField)
            }
        } else if let activeTextView = findActiveTextView() {
            // For text views, just dismiss — no return-to-commit behavior
            _ = activeTextView
        }

        clearObservations()
        initialValue = nil
        hasChanges = false
        applyDismissStyle()
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private func findActiveTextField() -> UITextField? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.findFirstResponder() as? UITextField }
            .first
    }

    private func findActiveTextView() -> UITextView? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.findFirstResponder() as? UITextView }
            .first
    }
}

// MARK: - Installer (swizzle becomeFirstResponder)

enum KeyboardToolbarInstaller {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true

        swizzle(UITextField.self,
                original: #selector(UITextField.becomeFirstResponder),
                swizzled: #selector(UITextField.mr_becomeFirstResponder))

        swizzle(UITextView.self,
                original: #selector(UITextView.becomeFirstResponder),
                swizzled: #selector(UITextView.mr_becomeFirstResponder))
    }

    private static func swizzle(_ cls: AnyClass, original: Selector, swizzled: Selector) {
        guard let m1 = class_getInstanceMethod(cls, original),
              let m2 = class_getInstanceMethod(cls, swizzled) else { return }
        method_exchangeImplementations(m1, m2)
    }
}

extension UITextField {
    @objc func mr_becomeFirstResponder() -> Bool {
        inputAccessoryView = KeyboardDismissAccessoryView.shared
        KeyboardDismissAccessoryView.shared.trackField(self)
        return mr_becomeFirstResponder() // calls original (swizzled)
    }
}

extension UITextView {
    @objc func mr_becomeFirstResponder() -> Bool {
        inputAccessoryView = KeyboardDismissAccessoryView.shared
        KeyboardDismissAccessoryView.shared.trackTextView(self)
        return mr_becomeFirstResponder() // calls original (swizzled)
    }
}

// MARK: - View Modifier (scroll-dismiss only)

private struct KeyboardManagedModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
    }
}

extension View {
    /// Enables interactive scroll-to-dismiss on this view's scroll views.
    /// The keyboard dismiss button is handled globally by KeyboardToolbarInstaller.
    func keyboardManaged() -> some View {
        modifier(KeyboardManagedModifier())
    }
}

// MARK: - UIView First Responder Finder

extension UIView {
    func findFirstResponder() -> UIView? {
        if isFirstResponder { return self }
        for sub in subviews {
            if let found = sub.findFirstResponder() { return found }
        }
        return nil
    }
}
