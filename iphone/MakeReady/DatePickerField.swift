//
//  DatePickerField.swift
//  MakeReady
//
//  Date and time picker field
//

import SwiftUI

struct DatePickerField: View {
    let label: String
    @Binding var date: Date
    @State private var showDatePicker = false
    @State private var showTimePicker = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack(spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)

            Spacer()

            // Date button
            Button(action: {
                showDatePicker = true
            }) {
                Text(dateFormatter.string(from: date))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $date, mode: .date)
            }

            // Time button
            Button(action: {
                showTimePicker = true
            }) {
                Text(timeFormatter.string(from: date))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .sheet(isPresented: $showTimePicker) {
                DatePickerSheet(date: $date, mode: .time)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// Sheet for date/time picker
struct DatePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var date: Date
    let mode: DatePickerMode

    enum DatePickerMode {
        case date
        case time
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: mode == .date ? [.date] : [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .padding()

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
                }
            }
        }
        .presentationDetents([.height(350)])
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            FieldGroup {
                DatePickerField(
                    label: "Date",
                    date: .constant(Date())
                )
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
    }
}
