//
//  BlockStyleEditor.swift
//  MakeReady
//
//  Reusable inline editor for read block styling: background image, color
//  overlay with opacity, and font size. Used by both the exegesis activity
//  editor and the read activity theme editor.
//
//  Layout (matches Figma design):
//    Title of the read block
//    [Image thumbnail] [Color swatch / toggle]
//    [Aa xs] [Aa s] [Aa m] [Aa lg] [Aa xl]
//

import SwiftUI
import PhotosUI

struct BlockStyleEditor: View {
    let activityId: String
    let blockId: String
    let blockTitle: String?
    /// Optional theme choices. When provided, a theme select menu is shown
    /// below the title and writes the selected theme to the read block.
    let availableThemes: [TextTheme]?
    /// Called when the color picker opens — parent can use this to scroll
    var onColorPickerOpened: (() -> Void)? = nil

    init(
        activityId: String,
        blockId: String,
        blockTitle: String? = nil,
        availableThemes: [TextTheme]? = nil,
        onColorPickerOpened: (() -> Void)? = nil
    ) {
        self.activityId = activityId
        self.blockId = blockId
        self.blockTitle = blockTitle
        self.availableThemes = availableThemes
        self.onColorPickerOpened = onColorPickerOpened
    }

    @Environment(OverlayManager.self) private var overlayManager

    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var pickedImage: UIImage? = nil
    @State private var isUploading = false
    @State private var localThemeId: String? = nil
    @State private var didSeedTheme = false

    private var block: ActivityReadBlock? {
        AppState.shared.activities[activityId]?.readBlocks?.first(where: { $0.id == blockId })
    }

    private var storedImageUrl: String? { block?.backgroundImageUrl }
    private var selectedColor: String? { block?.backgroundColor }
    private var storedThemeId: String? { block?.themeId }
    private var effectiveThemeId: String? { didSeedTheme ? localThemeId : storedThemeId }
    private var effectiveFontSize: String { block?.fontSize ?? "m" }

    var body: some View {
        VStack(spacing: 12) {
            // Block title (optional)
            if let blockTitle, !blockTitle.isEmpty {
                Text(blockTitle)
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Theme menu (optional)
            if let availableThemes {
                themePicker(themes: availableThemes)
            }

            // Image + Color row
            imageAndColorRow

            // Font size picker
            InlineFontSizePicker(
                selectedSize: effectiveFontSize,
                onSizeSelected: { key in
                    Task {
                        let writeValue: String? = (key == "m") ? nil : key
                        try? await ProgramActions().setReadBlockFontSize(
                            activityId: activityId,
                            blockId: blockId,
                            fontSize: writeValue
                        )
                    }
                }
            )
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fullScreenCover(isPresented: $showPhotoPicker) {
            PHPickerViewControllerWrapper(selectedImage: $pickedImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureWrapper(capturedImage: $pickedImage)
                .ignoresSafeArea()
        }
        .onAppear {
            localThemeId = storedThemeId
            didSeedTheme = true
        }
        .onChange(of: pickedImage) { _, newImage in
            guard let img = newImage else { return }
            Task { await uploadAndApply(img) }
        }
    }

    // MARK: - Theme Picker

    private func themePicker(themes: [TextTheme]) -> some View {
        FieldGroup {
            MenuInput(
                label: "Theme",
                options: themeOptions(from: themes),
                selectedOption: selectedThemeNameBinding(themes: themes)
            )
        }
    }

    private func themeOptions(from themes: [TextTheme]) -> [MenuInputOption] {
        [MenuInputOption("No Theme", description: "Plain text, no animation")] + themes
            .filter { $0.slug != "none" }
            .map { MenuInputOption($0.name, description: $0.description ?? "") }
    }

    private func selectedThemeNameBinding(themes: [TextTheme]) -> Binding<String> {
        Binding<String>(
            get: {
                if let id = effectiveThemeId,
                   let theme = themes.first(where: { $0.id == id }) {
                    return theme.name
                }
                return "No Theme"
            },
            set: { newName in
                let nextThemeId: String?
                if newName == "No Theme" {
                    nextThemeId = nil
                } else {
                    nextThemeId = themes.first(where: { $0.name == newName })?.id
                }

                guard nextThemeId != effectiveThemeId else { return }
                let previousThemeId = effectiveThemeId
                localThemeId = nextThemeId

                Task {
                    do {
                        try await ProgramActions().setReadBlockTheme(
                            activityId: activityId,
                            blockId: blockId,
                            themeId: nextThemeId
                        )
                    } catch {
                        NSLog("🎨 BlockStyleEditor: failed to set theme on block \(blockId): \(error.localizedDescription)")
                        await MainActor.run {
                            localThemeId = previousThemeId
                        }
                    }
                }
            }
        )
    }

    // MARK: - Image + Color Row

    private var imageAndColorRow: some View {
        HStack(spacing: 8) {
            // Left: Image thumbnail / placeholder
            Button {
                presentImageSourceMenu()
            } label: {
                ZStack {
                    Color.white.opacity(0.04)

                    if let url = storedImageUrl, let parsed = URL(string: url) {
                        GeometryReader { geo in
                            AsyncImage(url: parsed) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill()
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .clipped()
                                }
                            }
                        }
                    } else if !isUploading {
                        Image(systemName: "photo.on.rectangle")
                            .font(Typography.s22)
                            .foregroundColor(.white.opacity(0.3))
                    }

                    if isUploading {
                        Color.black.opacity(0.45)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isUploading)

            // Right: Color swatch / toggle
            Button {
                presentColorPicker()
            } label: {
                ZStack {
                    if let hex = selectedColor {
                        Color(hex: hex)
                    } else {
                        Color.white.opacity(0.04)

                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Color Picker

    private func presentColorPicker() {
        onColorPickerOpened?()
        overlayManager.presentMenu(id: "blockStyleColorPicker_\(blockId)") {
            BlockStyleColorPickerContent(
                activityId: activityId,
                blockId: blockId
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Image Actions

    private func presentImageSourceMenu() {
        overlayManager.present(.backgroundSourceMenu(blockId: blockId)) {
            BackgroundSourceMenu(
                onPickFromLibrary: {
                    overlayManager.present(.mediaLibraryPicker(blockId: blockId)) {
                        MediaLibraryPicker { item in
                            Task { await applyLibraryImage(url: item.url) }
                        }
                    }
                },
                onPickFromPhotos: { showPhotoPicker = true },
                onTakePhoto: { showCamera = true }
            )
        }
    }

    @MainActor
    private func applyLibraryImage(url: String) async {
        isUploading = true
        defer { isUploading = false }
        do {
            try await ProgramActions().setReadBlockBackground(
                activityId: activityId,
                blockId: blockId,
                imageUrl: url
            )
        } catch {
            NSLog("❌ BlockStyleEditor: Failed to apply library image: \(error)")
        }
    }

    @MainActor
    private func uploadAndApply(_ image: UIImage) async {
        isUploading = true
        defer { isUploading = false }
        do {
            let media = try await MediaActions().uploadPhoto(image: image, title: "Block background")
            try await ProgramActions().setReadBlockBackground(
                activityId: activityId,
                blockId: blockId,
                imageUrl: media.url
            )
        } catch {
            NSLog("❌ BlockStyleEditor: Failed to upload image: \(error)")
        }
    }
}

// MARK: - Color Picker Content (self-contained for menu presentation)

private struct BlockStyleColorPickerContent: View {
    let activityId: String
    let blockId: String

    @State private var localOpacity: Double = 0.8
    @State private var opacityWriteTask: Task<Void, Never>? = nil

    private var block: ActivityReadBlock? {
        AppState.shared.activities[activityId]?.readBlocks?.first(where: { $0.id == blockId })
    }

    private var selectedColor: String? { block?.backgroundColor }
    private var storedOpacity: Double? { block?.backgroundOverlayOpacity }

    private static let colorPalette: [String] = [
        // Row 1: purples + blues
        "#6c47ff", "#3e1bcc", "#1f0098", "#002198", "#9e173f", "#62001d",
        // Row 2: blues + pinks
        "#0981d1", "#44a6e7", "#4467e7", "#2245c1", "#ce3965", "#6b0002",
        // Row 3: teals + blues + greens
        "#005a55", "#1972c6", "#125798", "#003d77", "#119732", "#2f3341",
        // Row 4: teals + greens + black
        "#0d7a74", "#229e98", "#36bcb5", "#1fb444", "#00671a", "#000000",
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Non-lazy grid: this content animates up with the menu, and
            // LazyVGrid children realize only after the slide-up starts —
            // they land at their final position instead of riding the
            // animation (Class 2 — SWIFTUI_TRANSITIONS.md § LazyVStack and
            // Modal Animations). 24 swatches are trivially cheap to build
            // eagerly.
            VStack(spacing: 2) {
                ForEach(Array(stride(from: 0, to: Self.colorPalette.count, by: 6)), id: \.self) { rowStart in
                    HStack(spacing: 2) {
                        ForEach(Self.colorPalette[rowStart..<min(rowStart + 6, Self.colorPalette.count)], id: \.self) { hex in
                            swatch(hex)
                        }
                    }
                }
            }

            // Opacity slider
            HStack(spacing: 12) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(Typography.s14Semibold)
                    .foregroundColor(.white.opacity(selectedColor != nil ? 0.7 : 0.3))

                GeometryReader { geo in
                    let active = selectedColor != nil
                    let width = geo.size.width
                    let thumb: CGFloat = 20
                    let trackInset = thumb / 2
                    let usable = max(0, width - thumb)
                    let clamped = max(0, min(1, localOpacity))
                    let thumbX = trackInset + usable * clamped

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.white.opacity(active ? 0.95 : 0.3))
                            .frame(width: max(0, thumbX), height: 4)
                        Circle()
                            .fill(Color.white.opacity(active ? 1.0 : 0.3))
                            .frame(width: thumb, height: thumb)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .offset(x: thumbX - thumb / 2)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                guard active, usable > 0 else { return }
                                let raw = (g.location.x - trackInset) / usable
                                localOpacity = max(0, min(1, Double(raw)))
                                scheduleOpacityWrite(localOpacity)
                            }
                    )
                }
                .frame(height: 28)

                Text("\(Int(round(localOpacity * 100)))%")
                    .font(Typography.s13Semibold.monospacedDigit())
                    .foregroundColor(.white.opacity(selectedColor != nil ? 0.85 : 0.3))
                    .frame(width: 40, alignment: .trailing)
            }

            // Clear button
            Button {
                clearColor()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(Typography.s12Semibold)
                    Text("Clear")
                        .font(Typography.s13Semibold)
                }
                .foregroundColor(.white.opacity(selectedColor != nil ? 0.5 : 0.2))
            }
            .buttonStyle(.plain)
            .disabled(selectedColor == nil)
        }
        .onAppear { localOpacity = storedOpacity ?? 0.8 }
    }

    /// Swatch cell for the non-lazy color grid above.
    private func swatch(_ hex: String) -> some View {
        Button {
            pickColor(hex)
        } label: {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: hex))
                .frame(height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(
                            selectedColor?.caseInsensitiveCompare(hex) == .orderedSame
                                ? Color.white : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func pickColor(_ hex: String) {
        Task {
            let opacityToWrite: Double? = storedOpacity == nil ? 0.8 : nil
            try? await ProgramActions().setReadBlockBackground(
                activityId: activityId,
                blockId: blockId,
                color: hex,
                overlayOpacity: opacityToWrite
            )
            if opacityToWrite != nil {
                await MainActor.run { localOpacity = 0.8 }
            }
        }
    }

    private func clearColor() {
        Task {
            try? await ProgramActions().setReadBlockBackground(
                activityId: activityId,
                blockId: blockId,
                clearColor: true,
                clearOverlayOpacity: true
            )
        }
    }

    private func scheduleOpacityWrite(_ value: Double) {
        // Optimistic local update
        if var activity = AppState.shared.activities[activityId],
           var blocks = activity.readBlocks,
           let idx = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[idx].backgroundOverlayOpacity = value
            activity.readBlocks = blocks
            AppState.shared.activities.upsert(activity)
        }

        opacityWriteTask?.cancel()
        opacityWriteTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            try? await ProgramActions().setReadBlockBackground(
                activityId: activityId,
                blockId: blockId,
                overlayOpacity: value
            )
        }
    }
}
