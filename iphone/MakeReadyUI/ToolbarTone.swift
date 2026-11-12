//
//  ToolbarTone.swift
//  MakeReadyUI — the UI 2.0 module
//
//  activities-editor §27.1 (D38 finish): the shared tone type.
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

/// activities-editor §27.1 (D38): the paint of a control drawn over the page — `.light`
/// (default, today's paint, for a dark page) · `.dark` (`color-black`, for a light page). Shared by
/// the screen (`ActivitiesEditorScreen.State.toolbarTone`) and the components that take a
/// `toolbarTone` input: C-035 FilterChip, C-106 ChipStrip, C-102 IconButton, C-094
/// TextColorPalette and C-040 PageHeader.
enum ToolbarTone: String, Equatable {
    case light, dark
}
