//
//  SearchField.swift
//  MakeReady
//
//  Reusable animated search field component
//  Transitions between centered (default) and left-aligned (focused) states
//

import SwiftUI

struct SearchField: View {
    @Binding var isActive: Bool
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    let placeholder: String
    var onClose: (() -> Void)?
    var onClear: (() -> Void)?

    init(
        isActive: Binding<Bool>,
        searchText: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        placeholder: String = "Search",
        onClose: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self._isActive = isActive
        self._searchText = searchText
        self._isFocused = isFocused
        self.placeholder = placeholder
        self.onClose = onClose
        self.onClear = onClear
    }

    var body: some View {
        HStack(spacing: 8) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.white50)

                ZStack(alignment: .leading) {
                    if searchText.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white50)
                    }

                    TextField("", text: $searchText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white)
                        .focused($isFocused)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .allowsHitTesting(isActive)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? Color.white20 : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .onTapGesture {
                if !isActive {
                    withAnimation(Motion.standard) {
                        isActive = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
            }

            // Close button — outside the field
            if isActive {
                Button {
                    withAnimation(Motion.standard) {
                        searchText = ""
                        isActive = false
                        onClose?()
                        onClear?()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white50)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white20, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(Motion.standard, value: isActive)
    }
}

// MARK: - Preview

#Preview {
    SearchFieldPreview()
}

private struct SearchFieldPreview: View {
    @State private var isActive = false
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack {
                SearchField(
                    isActive: $isActive,
                    searchText: $searchText,
                    isFocused: $isFocused,
                    placeholder: "Search",
                    onClose: {
                        print("Close tapped")
                    },
                    onClear: {
                        print("Clear tapped")
                    }
                )
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .padding(.top, 60)
        }
    }
}
