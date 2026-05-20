//
//  ExegesisHighlightModal.swift
//  MakeReady
//
//  Full-screen takeover for highlighting exegesis verses.
//  Uses system text selection (becomeFirstResponder) since there's
//  no nested ScrollView — matching the Bible reader pattern.
//
//  Presented via overlayManager.present(priority: .topLevel) like AddActivityMenu.
//

import SwiftUI

struct ExegesisHighlightModal: View {
    let overlayManager: OverlayManager
    let plainText: String
    let highlights: [ExegesisHighlight]
    let canEdit: Bool
    let onHighlightCreated: (NSRange) -> Void
    let onHighlightTapped: (ExegesisHighlight) -> Void
    let onHighlightDeleted: (ExegesisHighlight) -> Void

    @State private var appeared = false
    @State private var pendingRange: NSRange? = nil
    @State private var selectedHighlight: ExegesisHighlight? = nil

    private var derivedSelections: [ReadBlockSelection] {
        highlights.map { ReadBlockSelection(start: $0.start, end: $0.end, style: "highlight") }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Highlight Passage")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .opacity(appeared ? 1 : 0)

            // Verse content — ExegesisVerseUIView is a UIScrollView,
            // so no SwiftUI ScrollView wrapper needed.
            ExegesisVerseView(
                plainText: plainText,
                highlights: derivedSelections,
                isSelectionEnabled: canEdit,
                fontSize: 16,
                usePreviewHighlightStyle: false,
                selectedHighlightRange: selectedHighlight.map {
                    NSRange(location: $0.start, length: $0.end - $0.start)
                },
                pendingRange: $pendingRange
            )
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.25).delay(0.05), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#07080C").ignoresSafeArea())
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: appeared)
        .onAppear { appeared = true }
        .onChange(of: pendingRange) { _, newRange in
            guard let range = newRange else { return }
            handlePendingRange(range)
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.15)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            overlayManager.dismiss(id: OverlayID.exegesisHighlightModal)
        }
    }

    private func handlePendingRange(_ range: NSRange) {
        defer {
            DispatchQueue.main.async { pendingRange = nil }
        }

        let start = range.location
        let end = range.location + range.length

        // If tapping an existing highlight, select it
        if let existing = highlights.first(where: { $0.start == start && $0.end == end }) {
            selectedHighlight = (selectedHighlight?.id == existing.id) ? nil : existing
            return
        }

        // New highlight
        selectedHighlight = nil
        onHighlightCreated(range)
    }

    @ViewBuilder
    private func highlightRow(_ h: ExegesisHighlight) -> some View {
        Button {
            onHighlightTapped(h)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snippet(for: h))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(h.noteMarkdown.isEmpty ? "Tap to add note" : "Note added")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if canEdit {
                    Button {
                        onHighlightDeleted(h)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func snippet(for highlight: ExegesisHighlight) -> String {
        let start = max(0, min(highlight.start, plainText.count))
        let end = max(0, min(highlight.end, plainText.count))
        if end <= start { return "Highlight" }
        let sIdx = plainText.index(plainText.startIndex, offsetBy: start)
        let eIdx = plainText.index(plainText.startIndex, offsetBy: end)
        return String(plainText[sIdx..<eIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
