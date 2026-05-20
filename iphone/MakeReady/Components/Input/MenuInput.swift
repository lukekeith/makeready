//
//  MenuInput.swift
//  MakeReady
//
//  Menu input with multiple picker style options
//

import SwiftUI

enum MenuInputStyle {
    case menu        // Default: Modal sheet with list
    case wheel       // Wheel picker (like iOS Timer)
    case inline      // Expandable inline picker
    case segmented   // Segmented control (best for 2-5 options)
}

struct MenuInputOption {
    let value: String
    let description: String?
    
    init(_ value: String, description: String? = nil) {
        self.value = value
        self.description = description
    }
}

struct MenuInput: View {
    let label: String
    let options: [String]
    let optionsWithDescriptions: [MenuInputOption]?
    @Binding var selectedOption: String
    let style: MenuInputStyle
    
    @State private var showPicker = false

    init(
        label: String,
        options: [String],
        selectedOption: Binding<String>,
        style: MenuInputStyle = .menu
    ) {
        self.label = label
        self.options = options
        self.optionsWithDescriptions = nil
        self._selectedOption = selectedOption
        self.style = style
    }
    
    init(
        label: String,
        options: [MenuInputOption],
        selectedOption: Binding<String>,
        style: MenuInputStyle = .menu
    ) {
        self.label = label
        self.options = options.map { $0.value }
        self.optionsWithDescriptions = options
        self._selectedOption = selectedOption
        self.style = style
    }

    var body: some View {
        switch style {
        case .menu:
            menuStyle
        case .wheel:
            wheelStyle
        case .inline:
            inlineStyle
        case .segmented:
            segmentedStyle
        }
    }
    
    // MARK: - Menu Style (Default)
    
    private var menuStyle: some View {
        Button(action: {
            showPicker = true
        }) {
            HStack(spacing: 8) {
                // Label
                Text(label)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)

                Spacer()

                // Selected value
                Text(selectedOption)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showPicker) {
            MenuPickerSheet(
                options: options,
                optionsWithDescriptions: optionsWithDescriptions,
                selectedOption: $selectedOption,
                isPresented: $showPicker
            )
        }
    }
    
    // MARK: - Wheel Style
    
    private var wheelStyle: some View {
        Button(action: {
            showPicker = true
        }) {
            HStack(spacing: 8) {
                // Label
                Text(label)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)

                Spacer()

                // Selected value
                Text(selectedOption)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showPicker) {
            WheelPickerSheet(
                label: label,
                options: options,
                selectedOption: $selectedOption,
                isPresented: $showPicker
            )
        }
    }
    
    // MARK: - Inline Style
    
    private var inlineStyle: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label button
            Button(action: {
                withAnimation {
                    showPicker.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)

                    Spacer()

                    Text(selectedOption)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)

                    Image(systemName: showPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Inline picker
            if showPicker {
                Picker(label, selection: $selectedOption) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }
    
    // MARK: - Segmented Style
    
    private var segmentedStyle: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            // Segmented control
            Picker(label, selection: $selectedOption) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .colorScheme(.dark)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Menu Picker Sheet

struct MenuPickerSheet: View {
    let options: [String]
    let optionsWithDescriptions: [MenuInputOption]?
    @Binding var selectedOption: String
    @Binding var isPresented: Bool

    /// Estimate the content height so the sheet hugs the list
    private var estimatedContentHeight: CGFloat {
        let hasDescriptions = optionsWithDescriptions != nil
        let rowHeight: CGFloat = hasDescriptions ? 58 : 44
        let listHeight = CGFloat(options.count) * rowHeight
        let chrome: CGFloat = 44 + 20 + 16 + 32 // toolbar + topPadding + horizontal padding + bottom safe area
        return min(listHeight + chrome, Screen.bounds.height * 0.9)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                selectedOption = option
                                isPresented = false
                            }) {
                                HStack(alignment: .center, spacing: 12) {
                                    // Title and optional description
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option)
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.white)
                                        
                                        if let description = optionDescription(for: option) {
                                            Text(description)
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    if option == selectedOption {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color(hex: "#6c47ff"))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())

                            if option != options.last {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color(hex: "#121522").opacity(1.0), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.height(estimatedContentHeight), .large])
        .presentationBackground {
            Color(hex: "#0D101A").opacity(0.8)
                .ignoresSafeArea()
        }
    }

    private func optionDescription(for value: String) -> String? {
        optionsWithDescriptions?.first { $0.value == value }?.description
    }
}

// MARK: - Wheel Picker Sheet

struct WheelPickerSheet: View {
    let label: String
    let options: [String]
    @Binding var selectedOption: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    
                    // Wheel picker
                    Picker(label, selection: $selectedOption) {
                        ForEach(options, id: \.self) { option in
                            Text(option)
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    .labelsHidden()
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color(hex: "#121522").opacity(1.0), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.height(300)])
        .presentationBackground {
            Color(hex: "#0D101A").opacity(0.8)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 20) {
                // Menu style (default)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Menu Style (Default)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white50)
                        .padding(.horizontal, 16)
                    
                    FieldGroup {
                        MenuInput(
                            label: "Max members",
                            options: ["Unlimited", "10", "25", "50", "100"],
                            selectedOption: .constant("Unlimited"),
                            style: .menu
                        )
                    }
                    .padding(.horizontal, 16)
                }
                
                // Menu style with descriptions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Menu Style with Descriptions")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white50)
                        .padding(.horizontal, 16)
                    
                    FieldGroup {
                        MenuInput(
                            label: "Visibility",
                            options: [
                                MenuInputOption("Public", description: "Anyone can find and join this program"),
                                MenuInputOption("Private", description: "Only invited members can access"),
                                MenuInputOption("Hidden", description: "Completely invisible to others")
                            ],
                            selectedOption: .constant("Public"),
                            style: .menu
                        )
                    }
                    .padding(.horizontal, 16)
                }
                
                // Wheel style
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wheel Style (Timer-like)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white50)
                        .padding(.horizontal, 16)
                    
                    FieldGroup {
                        MenuInput(
                            label: "Days",
                            options: (1...30).map { "\($0)" },
                            selectedOption: .constant("7"),
                            style: .wheel
                        )
                    }
                    .padding(.horizontal, 16)
                }
                
                // Segmented style
                VStack(alignment: .leading, spacing: 8) {
                    Text("Segmented Style (2-5 options)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white50)
                        .padding(.horizontal, 16)
                    
                    FieldGroup {
                        MenuInput(
                            label: "Visibility",
                            options: ["Public", "Private", "Hidden"],
                            selectedOption: .constant("Public"),
                            style: .segmented
                        )
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()
            }
            .padding(.top, 40)
        }
    }
}
