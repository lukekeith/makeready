//
//  BackgroundPickerModal.swift  (retained filename)
//  MakeReady
//
//  EditBlockBackgroundPage — full page that slides in from the right of the
//  Edit Themes screen when a read-block row's chevron is tapped. Structured
//  as the third pane in EditReadActivityPage's horizontal HStack:
//
//      Edit Activity  →  Edit Themes  →  Background  (this file)
//
//  Content mirrors the old bottom-sheet picker: image slot + color palette +
//  overlay-opacity slider + Reset. Dismissal is via the back chevron in the
//  page header (`onBack` callback), not a swipe-down gesture.
//

import SwiftUI
import PhotosUI

struct EditBlockBackgroundPage: View {
    let activityId: String
    let blockId: String
    /// Block title shown contextually (usually "Bible verse" or "Custom text").
    var blockTitle: String = ""
    /// Themes available for this organization — pre-loaded by the parent so
    /// the menu populates instantly. Pass an empty array while loading.
    var availableThemes: [TextTheme] = []
    /// Draft binding used by the parent's Edit Themes save flow. The picker
    /// reads and writes through this; the parent batch-saves on Save tap.
    var selectedThemeId: Binding<String?> = .constant(nil)
    /// Called when the user taps the back chevron in the page header.
    var onBack: () -> Void = {}
    /// Invoked after every server write so the parent can refresh any
    /// swatches / previews outside this page.
    var onChanged: (() -> Void)? = nil

    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var pickedImage: UIImage? = nil
    @State private var isUploading = false
    @State private var errorMessage: String? = nil

    @Environment(OverlayManager.self) private var overlayManager

    /// Local opacity value for the slider — drives both the live preview and
    /// (debounced) server writes. Kept in sync with the stored value so the
    /// slider feels responsive without requiring a round-trip per drag tick.
    @State private var localOpacity: Double = Self.defaultOverlayOpacity
    /// Debounce handle for slider → server writes.
    @State private var opacityWriteTask: Task<Void, Never>? = nil

    /// Live block (re-read each render so selection state reflects latest writes).
    private var block: ActivityReadBlock? {
        AppState.shared.activities[activityId]?.readBlocks?.first(where: { $0.id == blockId })
    }

    private var storedImageUrl: String? { block?.backgroundImageUrl }
    private var selectedColor:  String? { block?.backgroundColor }
    private var storedOpacity:  Double? { block?.backgroundOverlayOpacity }
    private var storedFontSize: String? { block?.fontSize }

    /// T-shirt font-size keys shown in the picker, smallest → largest.
    /// The em value for each is consumed only by the preview web client; here
    /// we render the letter glyphs at proportional point sizes so the user
    /// can see the relative scale without depending on the em map.
    private static let fontSizeKeys: [String] = ["xs", "s", "m", "lg", "xl"]

    /// Effective font size for rendering the selected-tile indicator. Nil
    /// stored value resolves to "m" (the default).
    private var effectiveFontSize: String { storedFontSize ?? "m" }

    private var hasSelection: Bool {
        storedImageUrl != nil || selectedColor != nil || storedFontSize != nil
    }

    /// Default overlay opacity applied on first color pick.
    static let defaultOverlayOpacity: Double = 0.8

    /// Effective opacity for render — stored value, or the default.
    private var effectiveOpacity: Double {
        storedOpacity ?? Self.defaultOverlayOpacity
    }

    private static let palette: [String] = EditBlockBackgroundPage.makePalette()
    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitleLink(
                    title: "Edit Theme",
                    leftIcon: "chevron.left",
                    rightLink: "Done",
                    onLeftIconTap: { onBack() },
                    onRightLinkTap: { onBack() }
                )

                ScrollView {
                    VStack(spacing: 16) {
                        themeFieldGroup
                            .padding(.horizontal, 16)

                        pickerBody
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .fullScreenCover(isPresented: $showPhotoPicker) {
            PHPickerViewControllerWrapper(selectedImage: $pickedImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureWrapper(capturedImage: $pickedImage)
                .ignoresSafeArea()
        }
        .onAppear { localOpacity = effectiveOpacity }
        .onChange(of: storedOpacity) { _, _ in
            // Keep local slider in sync if the stored value changes from
            // elsewhere (e.g. parent reset, remote sync).
            localOpacity = effectiveOpacity
        }
        .onChange(of: pickedImage) { _, newImage in
            guard let img = newImage else { return }
            Task { await uploadAndApply(img) }
        }
    }

    // MARK: - Theme picker field group

    /// Dropdown bound to the parent's draft `themeAssignments[blockId]`. The
    /// `MenuInput` exchanges theme NAMES (strings); we translate to/from the
    /// underlying themeId in the binding below.
    /// The server already ships a theme with slug "none"; we filter it out
    /// here and surface our own "No Theme" entry instead so picking it maps
    /// cleanly to a nil themeId (matching the rest of the app's conventions).
    @ViewBuilder
    private var themeFieldGroup: some View {
        FieldGroup {
            MenuInput(
                label: "Theme",
                options: [
                    MenuInputOption("No Theme", description: "Plain text, no animation")
                ] + availableThemes
                    .filter { $0.slug != "none" }
                    .map { MenuInputOption($0.name, description: $0.description ?? "") },
                selectedOption: selectedThemeNameBinding
            )
        }
    }

    private var selectedThemeNameBinding: Binding<String> {
        Binding<String>(
            get: {
                if let id = selectedThemeId.wrappedValue,
                   let name = availableThemes.first(where: { $0.id == id })?.name {
                    return name
                }
                return "No Theme"
            },
            set: { newName in
                if newName == "No Theme" {
                    selectedThemeId.wrappedValue = nil
                } else if let t = availableThemes.first(where: { $0.name == newName }) {
                    selectedThemeId.wrappedValue = t.id
                }
            }
        )
    }

    // MARK: - Picker body

    @ViewBuilder
    private var pickerBody: some View {
        let screenWidth  = Screen.bounds.width
        let contentWidth = max(0, screenWidth - 32)
        let gap: CGFloat = 8
        let colWidth     = max(0, (contentWidth - gap) / 2)
        let tileSize     = max(0, (colWidth - 12) / 4)
        let rowHeight    = tileSize * 8 + 4 * 7

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: gap) {
                imageSlot(width: colWidth, height: rowHeight)

                LazyVGrid(columns: colorColumns, spacing: 4) {
                    ForEach(Self.palette, id: \.self) { hex in
                        Button {
                            Task { await pickColor(hex) }
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: hex))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(
                                            selectedColor?.caseInsensitiveCompare(hex) == .orderedSame
                                                ? Color.white
                                                : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)
                    }
                }
                .frame(width: colWidth, height: rowHeight)
            }
            .frame(width: contentWidth, height: rowHeight)
            .padding(.horizontal, 16)

            fontSizePicker
                .padding(.horizontal, 16)

            opacitySlider
                .padding(.horizontal, 16)

            Button {
                Task { await reset() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .semibold))
                    Text(hasSelection ? "Reset" : "Use default")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .disabled(isUploading)
            .padding(.horizontal, 16)

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Image slot

    private func imageSlot(width: CGFloat, height: CGFloat) -> some View {
        Button {
            presentSourceMenu()
        } label: {
            ZStack {
                Color.white.opacity(0.04)

                if let url = storedImageUrl, let parsed = URL(string: url) {
                    AsyncImage(url: parsed) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.clear
                        }
                    }
                    .frame(width: width, height: height)
                    .clipped()
                } else if !isUploading {
                    Image(systemName: "camera")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundColor(.white)
                }

                if let hex = selectedColor {
                    Color(hex: hex)
                        .opacity(storedImageUrl == nil ? 1.0 : localOpacity)
                        .allowsHitTesting(false)
                }

                if isUploading {
                    Color.black.opacity(0.45)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        hasSelection ? Color.white : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
    }

    // MARK: - Font size picker

    /// Horizontal 5-up grid of t-shirt sizes (xs/s/m/lg/xl). Each tile
    /// renders an "Aa" glyph at a point size proportional to the em value
    /// the preview uses, so the user sees the relative scale at a glance.
    /// The currently-selected tile (nil → "m") gets a white 2px stroke,
    /// matching the color-swatch selection treatment above.
    @ViewBuilder
    private var fontSizePicker: some View {
        HStack(spacing: 4) {
            ForEach(Self.fontSizeKeys, id: \.self) { key in
                let isSelected = effectiveFontSize == key
                Button {
                    Task { await pickFontSize(key) }
                } label: {
                    Text("Aa")
                        .font(.system(size: Self.fontSizePointSize(key), weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    isSelected ? Color.white : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Point size used only for the picker tile's "Aa" preview glyph.
    /// Proportional to the em value the preview renders with:
    ///   xs = 1.0em, s = 1.2em, m = 1.4em (default), lg = 1.7em, xl = 2.0em
    /// Multiply by 13 (the preview's root-font-size cap) to get the display pt.
    private static func fontSizePointSize(_ key: String) -> CGFloat {
        switch key {
        case "xs": return 13
        case "s":  return 16
        case "m":  return 19
        case "lg": return 23
        case "xl": return 27
        default:   return 19
        }
    }

    // MARK: - Opacity slider

    @ViewBuilder
    private var opacitySlider: some View {
        let active = selectedColor != nil
        HStack(spacing: 12) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(active ? 0.7 : 0.3))

            OpacitySlider(
                value: Binding(
                    get: { localOpacity },
                    set: { newValue in
                        localOpacity = newValue
                        scheduleOpacityWrite(newValue)
                    }
                ),
                isActive: active
            )
            .frame(height: 28)
            .frame(maxWidth: .infinity)

            Text("\(Int(round(localOpacity * 100)))%")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(.white.opacity(active ? 0.85 : 0.4))
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func scheduleOpacityWrite(_ value: Double) {
        opacityWriteTask?.cancel()
        opacityWriteTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            await writeOpacity(value)
        }
    }

    @MainActor
    private func writeOpacity(_ value: Double) async {
        guard selectedColor != nil else { return }
        do {
            try await ProgramActions().setReadBlockBackground(
                activityId:     activityId,
                blockId:        blockId,
                overlayOpacity: value
            )
            onChanged?()
        } catch is CancellationError {
            // Expected — debounce cancelled this request in favor of a newer one
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            // URLSession cancellation from task cancel — also expected
        } catch {
            errorMessage = "Couldn't save opacity: \(error.localizedDescription)"
        }
    }

    /// Write the tapped size key through to the server. Tapping "m" while
    /// nothing is stored is a no-op since "m" is the default; otherwise send
    /// the value (or nil to clear). Updates AppState optimistically via the
    /// action so the picker's border shifts immediately.
    private func pickFontSize(_ key: String) async {
        let writeValue: String? = (key == "m") ? nil : key
        do {
            try await ProgramActions().setReadBlockFontSize(
                activityId: activityId,
                blockId:    blockId,
                fontSize:   writeValue
            )
            onChanged?()
        } catch {
            await MainActor.run { errorMessage = "Couldn't save size: \(error.localizedDescription)" }
        }
    }

    private func pickColor(_ hex: String) async {
        do {
            let opacityToWrite: Double? =
                storedOpacity == nil ? Self.defaultOverlayOpacity : nil

            try await ProgramActions().setReadBlockBackground(
                activityId:     activityId,
                blockId:        blockId,
                color:          hex,
                overlayOpacity: opacityToWrite
            )
            await MainActor.run {
                if opacityToWrite != nil {
                    localOpacity = Self.defaultOverlayOpacity
                }
            }
            onChanged?()
        } catch {
            await MainActor.run { errorMessage = "Couldn't save: \(error.localizedDescription)" }
        }
    }

    private func reset() async {
        guard hasSelection else { return }
        opacityWriteTask?.cancel()
        do {
            try await ProgramActions().setReadBlockBackground(
                activityId:           activityId,
                blockId:              blockId,
                clearImage:           true,
                clearColor:           true,
                clearOverlayOpacity:  true
            )
            // Clear the font-size separately — it lives on a different
            // action boundary but is part of what "Reset" means to the user.
            if storedFontSize != nil {
                try await ProgramActions().setReadBlockFontSize(
                    activityId: activityId,
                    blockId:    blockId,
                    fontSize:   nil
                )
            }
            await MainActor.run { localOpacity = Self.defaultOverlayOpacity }
            onChanged?()
        } catch {
            await MainActor.run { errorMessage = "Couldn't reset: \(error.localizedDescription)" }
        }
    }

    /// Show the bottom-sheet source picker (Library / Photos / Camera).
    private func presentSourceMenu() {
        overlayManager.present(.backgroundSourceMenu(blockId: blockId)) {
            BackgroundSourceMenu(
                onPickFromLibrary: presentLibraryPicker,
                onPickFromPhotos:  { showPhotoPicker = true },
                onTakePhoto:       { showCamera = true }
            )
        }
    }

    /// Show the media-library grid picker as a managed modal. On selection
    /// the chosen URL is written straight to the read block (no upload —
    /// the image is already in the org's media library).
    private func presentLibraryPicker() {
        overlayManager.present(.mediaLibraryPicker(blockId: blockId)) {
            MediaLibraryPicker { item in
                Task { await applyLibraryImage(url: item.url) }
            }
        }
    }

    @MainActor
    private func applyLibraryImage(url: String) async {
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            try await ProgramActions().setReadBlockBackground(
                activityId: activityId,
                blockId:    blockId,
                imageUrl:   url
            )
            onChanged?()
        } catch {
            errorMessage = "Couldn't apply image: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func uploadAndApply(_ image: UIImage) async {
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            let media = try await MediaActions().uploadPhoto(image: image, title: "Read block background")
            try await ProgramActions().setReadBlockBackground(
                activityId: activityId,
                blockId:    blockId,
                imageUrl:   media.url
            )
            onChanged?()
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Custom slider (pure SwiftUI — UIKit Slider renders broken when
    // its parent uses `.drawingGroup()`, and this page is animated inside one.)

    private struct OpacitySlider: View {
        @Binding var value: Double      // 0...1
        let isActive: Bool

        var body: some View {
            GeometryReader { geo in
                let width  = geo.size.width
                let thumb: CGFloat = 20
                let trackInset = thumb / 2
                let usable  = max(0, width - thumb)
                let clamped = max(0, min(1, value))
                let thumbX  = trackInset + usable * clamped

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.white.opacity(isActive ? 0.95 : 0.5))
                        .frame(width: max(0, thumbX), height: 4)

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumb, height: thumb)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: thumbX - thumb / 2)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .opacity(isActive ? 1.0 : 0.4)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            guard isActive, usable > 0 else { return }
                            let raw = (g.location.x - trackInset) / usable
                            value = max(0, min(1, Double(raw)))
                        }
                )
            }
        }
    }

    // MARK: - Palette

    private static func makePalette() -> [String] {
        // 4 cols × 8 rows. Row 1 is neutrals (dark / medium / lighter charcoal
        // + light gray); each subsequent row is a hue family with a deep and a
        // bright variant so similar shades aren't adjacent.
        [
            "#18181B", "#3F3F46", "#71717A", "#A1A1AA", // charcoals + light gray
            "#7F1D1D", "#DC2626", "#BE185D", "#F472B6", // reds + rose
            "#9A3412", "#EA580C", "#B45309", "#FBBF24", // oranges + ambers
            "#854D0E", "#CA8A04", "#65A30D", "#84CC16", // yellows + limes
            "#14532D", "#16A34A", "#064E3B", "#34D399", // greens
            "#134E4A", "#0D9488", "#0891B2", "#06B6D4", // teals + cyans
            "#1E3A8A", "#2563EB", "#1D4ED8", "#60A5FA", // blues
            "#4C1D95", "#7C3AED", "#9333EA", "#C026D3", // purples + magentas
        ]
    }
}
