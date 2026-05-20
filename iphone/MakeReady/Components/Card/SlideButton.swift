//
//  SlideButton.swift
//  MakeReady
//
//  Configuration for swipeable card action buttons
//

import SwiftUI

public enum SlideButtonStyle {
    case reschedule   // Blue background (#5680ff) - for rescheduling events/studies
    case delete       // Red background (#df1439) - for destructive actions
    case skip         // White 20% background - for skip/forward actions
    case edit         // White 20% background - for edit actions
}

public struct SlideButton: Identifiable {
    public let id = UUID()
    public let icon: String
    public let style: SlideButtonStyle
    public let action: () -> Void

    public init(
        icon: String,
        style: SlideButtonStyle = .skip,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.action = action
    }
}
