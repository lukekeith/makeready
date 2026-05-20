//
//  TagInput.swift
//  MakeReady
//
//  Tag input with inline text field, removable tag pills, and autocomplete suggestions.
//

import SwiftUI

struct TagInput: View {
    @Binding var tags: [String]
    let placeholder: String
    var originalTags: Set<String>? = nil  // When set, tags not in this set appear muted (unsaved)
    var onRequestSuggestions: (() async -> [String])? = nil

    @State private var inputText: String = ""
    @State private var suggestions: [String] = []
    @State private var showSuggestions: Bool = false
    @State private var isLoadingSuggestions: Bool = false
    @FocusState private var isFocused: Bool

    private var filteredSuggestions: [String] {
        let available = suggestions.filter { !tags.contains($0) }
        if inputText.isEmpty {
            return available
        }
        return available.filter { $0.localizedCaseInsensitiveContains(inputText) }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Tags + text field
            VStack(alignment: .leading, spacing: 8) {
                if !tags.isEmpty {
                    FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            let isNew = originalTags != nil && !originalTags!.contains(tag)
                            TagPill(tag: tag, isNew: isNew) {
                                removeTag(tag)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                TextField(placeholder, text: $inputText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { addTag(inputText) }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // AI suggestion button
            if onRequestSuggestions != nil && !showSuggestions {
                Button {
                    loadSuggestions()
                } label: {
                    HStack(spacing: 6) {
                        if isLoadingSuggestions {
                            ProgressView()
                                .tint(.white.opacity(0.5))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .medium))
                        }
                        Text("AI tag suggestions")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingSuggestions)
            }

            // Suggestions
            if showSuggestions && !filteredSuggestions.isEmpty {
                VStack(spacing: 8) {
                    // Header with hide button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSuggestions = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Hide suggestions")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))

                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            SuggestionPill(tag: suggestion) {
                                addTag(suggestion)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Actions

    private func loadSuggestions() {
        guard let onRequestSuggestions, !isLoadingSuggestions else { return }
        isLoadingSuggestions = true
        Task {
            let result = await onRequestSuggestions()
            await MainActor.run {
                isLoadingSuggestions = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    suggestions = result
                    showSuggestions = true
                }
            }
        }
    }

    private func addTag(_ raw: String) {
        let normalized = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !tags.contains(normalized) else {
            inputText = ""
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            tags.append(normalized)
        }
        inputText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeTag(_ tag: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            tags.removeAll { $0 == tag }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Tag Pill (selected tag)

private struct TagPill: View {
    let tag: String
    var isNew: Bool = false
    let onRemove: () -> Void

    var body: some View {
        Button {
            onRemove()
        } label: {
            HStack(spacing: 4) {
                Text(tag)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isNew ? .white.opacity(0.5) : .white)

                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isNew ? .white.opacity(0.4) : .white.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Capsule().fill(isNew ? Color.white.opacity(0.1) : Color.brandPrimary))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

// MARK: - Suggestion Pill

private struct SuggestionPill: View {
    let tag: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(tag)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 24) {
            // Empty state
            TagInputPreview(
                initialTags: [],
                label: "Empty"
            )

            // With tags
            TagInputPreview(
                initialTags: ["sermon", "worship", "youth"],
                label: "With Tags"
            )

            // Many tags
            TagInputPreview(
                initialTags: ["sermon", "worship", "youth", "bible-study", "prayer", "missions", "outreach"],
                label: "Many Tags"
            )
        }
        .padding(16)
    }
}

private struct TagInputPreview: View {
    @State var tags: [String]
    let label: String

    init(initialTags: [String], label: String) {
        _tags = State(initialValue: initialTags)
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)

            TagInput(
                tags: $tags,
                placeholder: "Add tag...",
                onRequestSuggestions: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    return ["sermon", "worship", "youth", "bible-study", "prayer", "missions", "outreach", "community"]
                }
            )
        }
    }
}
