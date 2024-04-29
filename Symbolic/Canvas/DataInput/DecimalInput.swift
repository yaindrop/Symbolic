import Foundation
import SwiftUI

// MARK: - DecimalInput

func sanitized(decimalStr: String) -> String {
    let filtered = decimalStr.filter { "0123456789.".contains($0) }
    let dotSplit = filtered.split(separator: ".", omittingEmptySubsequences: false)
    let remaining = dotSplit.dropFirst()
    return (dotSplit.first ?? "") + (remaining.isEmpty ? "" : "." + remaining.joined(separator: ""))
}

func decimalFormatStyle<Value>(maxFredgeDigits: Int = 3) -> FloatingPointFormatStyle<Value> {
    FloatingPointFormatStyle<Value>().precision(.fractionLength(0 ... maxFredgeDigits))
}

struct DecimalInput: View {
    var body: some View {
        TextField(title, text: $inputText)
            .keyboardType(.numberPad)
            .onChange(of: inputText) {
                inputText = sanitizer(inputText)
                inputNumber = Double(inputText) ?? inputNumber
            }
            .onChange(of: inputNumber) {
                if inputNumber != Double(inputText) {
                    inputText = inputNumber.formatted(formatStyle)
                }
            }
            .font(.body.monospacedDigit())
    }

    init(title: String,
         inputNumber: Binding<Double>,
         formatStyle: FloatingPointFormatStyle<Double> = decimalFormatStyle(),
         sanitizer: @escaping (String) -> String = sanitized(decimalStr:)) {
        self.title = title
        _inputNumber = inputNumber
        inputText = inputNumber.wrappedValue.formatted(formatStyle)
        self.formatStyle = formatStyle
        self.sanitizer = sanitizer
    }

    // MARK: private

    private let title: String
    @Binding private var inputNumber: Double
    private let formatStyle: FloatingPointFormatStyle<Double>
    private let sanitizer: (String) -> String

    @State private var inputText: String
}
