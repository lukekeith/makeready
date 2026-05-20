//
//  InputTypes.swift
//  MakeReady
//
//  Shared input types, formatters, and validators for text input fields
//

import SwiftUI

// MARK: - Input Type

enum InputType {
    case alphanumeric
    case phone
    case integer
    case float
    case currency
    case email
    case percentage

    var keyboardType: UIKeyboardType {
        switch self {
        case .alphanumeric:
            return .default
        case .phone:
            return .numberPad
        case .integer:
            return .numberPad
        case .float, .currency, .percentage:
            return .decimalPad
        case .email:
            return .emailAddress
        }
    }

    var icon: String? {
        switch self {
        case .currency:
            return "dollarsign"
        case .percentage:
            return "percent"
        case .email:
            return "envelope.fill"
        case .phone:
            return "phone.fill"
        default:
            return nil
        }
    }
}

// MARK: - Input Formatter

class InputFormatter {

    // Format input based on type
    static func format(_ text: String, for type: InputType) -> String {
        switch type {
        case .phone:
            return formatPhone(text)
        case .integer:
            return formatInteger(text)
        case .float:
            return formatFloat(text)
        case .currency:
            return formatCurrency(text)
        case .percentage:
            return formatPercentage(text)
        case .alphanumeric, .email:
            return text
        }
    }

    // Get raw value (unformatted) from formatted text
    static func unformat(_ text: String, for type: InputType) -> String {
        switch type {
        case .phone:
            return text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        case .currency, .integer:
            return text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        case .float, .percentage:
            return text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        case .alphanumeric, .email:
            return text
        }
    }

    // MARK: - Phone Formatter

    private static func formatPhone(_ text: String) -> String {
        // Remove all non-numeric characters
        let digits = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // Limit to 10 digits
        let limited = String(digits.prefix(10))

        // Format as (###) ###-####
        var formatted = ""
        for (index, char) in limited.enumerated() {
            if index == 0 {
                formatted += "("
            } else if index == 3 {
                formatted += ") "
            } else if index == 6 {
                formatted += "-"
            }
            formatted.append(char)
        }

        return formatted
    }

    // MARK: - Integer Formatter

    private static func formatInteger(_ text: String) -> String {
        // Remove all non-numeric characters
        let digits = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // Return as-is (could add thousand separators if desired)
        return digits
    }

    // MARK: - Float Formatter

    private static func formatFloat(_ text: String) -> String {
        // Allow digits and one decimal point
        let allowed = text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)

        // Ensure only one decimal point
        let parts = allowed.components(separatedBy: ".")
        if parts.count > 2 {
            return parts[0] + "." + parts[1]
        }

        return allowed
    }

    // MARK: - Currency Formatter

    private static func formatCurrency(_ text: String) -> String {
        // Remove all non-numeric characters
        let digits = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // If empty, return empty
        if digits.isEmpty {
            return ""
        }

        // Convert to cents (integer)
        guard let amount = Int(digits) else { return "" }

        // Format with thousand separators and decimal
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let dollars = Double(amount) / 100.0
        return formatter.string(from: NSNumber(value: dollars)) ?? ""
    }

    // MARK: - Percentage Formatter

    private static func formatPercentage(_ text: String) -> String {
        // Allow digits and one decimal point
        let allowed = text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)

        // Ensure only one decimal point
        let parts = allowed.components(separatedBy: ".")
        if parts.count > 2 {
            return parts[0] + "." + parts[1]
        }

        // Limit to 100
        if let value = Double(allowed), value > 100 {
            return "100"
        }

        return allowed
    }
}

// MARK: - Input Validator

class InputValidator {

    static func validate(_ text: String, for type: InputType) -> String? {
        switch type {
        case .phone:
            return validatePhone(text)
        case .integer:
            return validateInteger(text)
        case .float:
            return validateFloat(text)
        case .currency:
            return validateCurrency(text)
        case .email:
            return validateEmail(text)
        case .percentage:
            return validatePercentage(text)
        case .alphanumeric:
            return nil // No validation
        }
    }

    // MARK: - Phone Validator

    private static func validatePhone(_ text: String) -> String? {
        let digits = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        if digits.isEmpty {
            return nil // Empty is valid (not required)
        }

        if digits.count < 10 {
            return "Phone number must be 10 digits"
        }

        return nil
    }

    // MARK: - Integer Validator

    private static func validateInteger(_ text: String) -> String? {
        if text.isEmpty {
            return nil
        }

        if Int(text) == nil {
            return "Must be a valid integer"
        }

        return nil
    }

    // MARK: - Float Validator

    private static func validateFloat(_ text: String) -> String? {
        if text.isEmpty {
            return nil
        }

        if Double(text) == nil {
            return "Must be a valid number"
        }

        return nil
    }

    // MARK: - Currency Validator

    private static func validateCurrency(_ text: String) -> String? {
        if text.isEmpty {
            return nil
        }

        // Remove thousand separators
        let cleaned = text.replacingOccurrences(of: ",", with: "")

        if Double(cleaned) == nil {
            return "Must be a valid amount"
        }

        return nil
    }

    // MARK: - Email Validator

    private static func validateEmail(_ text: String) -> String? {
        if text.isEmpty {
            return nil
        }

        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: text) {
            return "Must be a valid email address"
        }

        return nil
    }

    // MARK: - Percentage Validator

    private static func validatePercentage(_ text: String) -> String? {
        if text.isEmpty {
            return nil
        }

        guard let value = Double(text) else {
            return "Must be a valid percentage"
        }

        if value < 0 || value > 100 {
            return "Must be between 0 and 100"
        }

        return nil
    }
}
