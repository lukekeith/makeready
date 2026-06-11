//
//  AddActivityMenu.swift
//  MakeReady
//
//  Full-screen modal for selecting an activity type to add to a lesson.
//  Fades in with staggered card animations.
//

import SwiftUI

struct AddActivityMenu: View {
    let overlayManager: OverlayManager
    let existingActivityTypes: [String]
    let onActivitySelected: (String) -> Void

    @State private var appeared = false

    private let activityTypes: [(id: String, title: String, image: CardActivityTypeImage, labelColor: Color, iconColor: Color)] = [
        ("READ", "Read", .asset(name: ActivityStyle.icon(forRawType: "READ"), backgroundColor: ActivityStyle.color(forRawType: "READ")), ActivityStyle.labelColor(forRawType: "READ"), ActivityStyle.iconColor(forRawType: "READ")),
        ("USER_INPUT", "Write", .asset(name: ActivityStyle.icon(forRawType: "USER_INPUT"), backgroundColor: ActivityStyle.color(forRawType: "USER_INPUT")), ActivityStyle.labelColor(forRawType: "USER_INPUT"), ActivityStyle.iconColor(forRawType: "USER_INPUT")),
        ("VIDEO", "Video", .asset(name: ActivityStyle.icon(forRawType: "VIDEO"), backgroundColor: ActivityStyle.color(forRawType: "VIDEO")), ActivityStyle.labelColor(forRawType: "VIDEO"), ActivityStyle.iconColor(forRawType: "VIDEO")),
        ("YOUTUBE", "YouTube", .asset(name: ActivityStyle.icon(forRawType: "YOUTUBE"), backgroundColor: ActivityStyle.color(forRawType: "YOUTUBE")), ActivityStyle.labelColor(forRawType: "YOUTUBE"), ActivityStyle.iconColor(forRawType: "YOUTUBE")),
        ("EXEGESIS", "Exegesis", .asset(name: ActivityStyle.icon(forRawType: "EXEGESIS"), backgroundColor: ActivityStyle.color(forRawType: "EXEGESIS")), ActivityStyle.labelColor(forRawType: "EXEGESIS"), ActivityStyle.iconColor(forRawType: "EXEGESIS")),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select activity")
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

            Spacer().frame(height: 32)

            // 3-column grid with staggered fade
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(Array(activityTypes.enumerated()), id: \.element.id) { index, activityType in
                    CardActivityType(
                        title: activityType.title,
                        image: activityType.image,
                        mode: .grid,
                        labelColor: activityType.labelColor,
                        iconColor: activityType.iconColor,
                        onTap: {
                            onActivitySelected(activityType.id)
                            dismiss()
                        }
                    )
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .animation(
                        Motion.pagePushBrisk.delay(Double(index) * 0.05),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#07080C").ignoresSafeArea())
        .opacity(appeared ? 1 : 0)
        .animation(Motion.settle, value: appeared)
        .onAppear {
            appeared = true
        }
    }

    private func dismiss() {
        withAnimation(Motion.exitFast) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            overlayManager.dismiss(id: OverlayID.addActivityMenu)
        }
    }
}

// MARK: - Preview

#Preview {
    AddActivityMenu(
        overlayManager: OverlayManager(),
        existingActivityTypes: [],
        onActivitySelected: { activityType in
            print("Selected: \(activityType)")
        }
    )
}
