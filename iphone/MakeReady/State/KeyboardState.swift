//
//  KeyboardState.swift
//  MakeReady
//
//  Centralized keyboard observer. Any SwiftUI view that reads
//  .height or .isVisible in its body will auto-rerender when the
//  keyboard appears or disappears.
//

import SwiftUI
import UIKit
import Combine

@Observable
final class KeyboardState {
    static let shared = KeyboardState()

    private(set) var height: CGFloat = 0
    var isVisible: Bool { height > 0 }

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
            .sink { [weak self] h in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.height = h
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.height = 0
                }
            }
            .store(in: &cancellables)
    }
}
