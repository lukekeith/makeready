//
//  SwipeState.swift
//  MakeReady
//
//  Environment-based swipe state for coordinating scroll locking.
//  When a SwipeableCard is being swiped, parent ScrollViews can
//  read this state to disable scrolling.
//

import SwiftUI

/// Observable object that tracks whether a card swipe is in progress
class SwipeState: ObservableObject {
    @Published var isSwiping: Bool = false
}

/// Environment key for SwipeState
struct SwipeStateKey: EnvironmentKey {
    static let defaultValue: SwipeState? = nil
}

extension EnvironmentValues {
    var swipeState: SwipeState? {
        get { self[SwipeStateKey.self] }
        set { self[SwipeStateKey.self] = newValue }
    }
}
