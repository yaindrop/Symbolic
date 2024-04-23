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

// MARK: - PositionPicker

struct PositionPicker: View {
    var body: some View {
        HStack {
            if isInputMode {
                content.onChange(of: inputPosition) { onChange(inputPosition) }
            } else {
                Menu {
                    Button { isInputMode = true } label: { Text("Input") }
                } label: {
                    content
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 20)
        .padding(6)
        .background(Color.tertiarySystemBackground)
        .cornerRadius(6)
    }

    init(position: Point2,
         onChange: @escaping (Point2) -> Void = { _ in },
         onDone: @escaping (Point2) -> Void = { _ in }) {
        self.position = position
        self.onChange = onChange
        self.onDone = onDone
        inputX = position.x
        inputY = position.y
    }

    // MARK: private

    private let position: Point2
    private let onChange: (Point2) -> Void
    private let onDone: (Point2) -> Void

    @State private var isInputMode: Bool = false
    @State private var inputX: Double
    @State private var inputY: Double

    private var inputPosition: Point2 { Point2(inputX, inputY) }

    private var content: some View {
        Group {
            if isInputMode {
                Button {
                    isInputMode = false
                    onDone(inputPosition)
                } label: { Image(systemName: "checkmark.circle") }
            }
            Image(systemName: "arrow.right")
            if isInputMode {
                DecimalInput(title: "X", inputNumber: $inputX)
            } else {
                Text(position.x.formatted(decimalFormatStyle()))
            }
            Rectangle().frame(width: 1).background(Color.label)
            Image(systemName: "arrow.down")
            if isInputMode {
                DecimalInput(title: "Y", inputNumber: $inputY)
            } else {
                Text(position.y.formatted(decimalFormatStyle()))
            }
        }
        .font(.callout.monospacedDigit())
    }
}

// MARK: - SizePicker

struct SizePicker: View {
    var body: some View {
        HStack {
            if isInputMode {
                content.onChange(of: inputSize) { onChange(inputSize) }
            } else {
                Menu {
                    Button { isInputMode = true } label: { Text("Input") }
                } label: {
                    content
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 20)
        .padding(6)
        .background(Color.tertiarySystemBackground)
        .cornerRadius(6)
    }

    init(size: CGSize,
         onChange: @escaping (CGSize) -> Void = { _ in },
         onDone: @escaping (CGSize) -> Void = { _ in }) {
        self.size = size
        self.onChange = onChange
        self.onDone = onDone
        inputW = size.width
        inputH = size.height
    }

    // MARK: private

    private let size: CGSize
    private let onChange: (CGSize) -> Void
    private let onDone: (CGSize) -> Void

    @State private var isInputMode: Bool = false
    @State private var inputW: Double
    @State private var inputH: Double

    private var inputSize: CGSize { CGSize(inputW, inputH) }

    private var content: some View {
        Group {
            if isInputMode {
                Button {
                    isInputMode = false
                    onDone(inputSize)
                } label: { Image(systemName: "checkmark.circle") }
            }
            Image(systemName: "arrow.left.and.right")
            if isInputMode {
                DecimalInput(title: "Width", inputNumber: $inputW)
            } else {
                Text(size.width.formatted(decimalFormatStyle()))
            }
            Rectangle().frame(width: 1).background(Color.label)
            Image(systemName: "arrow.up.and.down")
            if isInputMode {
                DecimalInput(title: "Height", inputNumber: $inputH)
            } else {
                Text(size.height.formatted(decimalFormatStyle()))
            }
        }
        .font(.callout.monospacedDigit())
    }
}

// MARK: - AnglePicker

struct AnglePicker: View {
    var body: some View {
        HStack {
            if isInputMode {
                content.onChange(of: inputAngle) { onChange(inputAngle) }
            } else {
                Menu {
                    Button { isInputMode = true } label: { Text("Input") }
                } label: {
                    content
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 20)
        .padding(6)
        .background(Color.tertiarySystemBackground)
        .cornerRadius(6)
    }

    init(angle: Angle,
         onChange: @escaping (Angle) -> Void = { _ in },
         onDone: @escaping (Angle) -> Void = { _ in }) {
        self.angle = angle
        self.onChange = onChange
        self.onDone = onDone
        isRadians = false
        inputNumber = angle.degrees
    }

    // MARK: private

    private let angle: Angle
    private let onChange: (Angle) -> Void
    private let onDone: (Angle) -> Void

    @State private var isRadians: Bool
    @State private var isInputMode: Bool = false
    @State private var inputNumber: Double

    private var angleValue: Double { isRadians ? angle.radians : angle.degrees }
    private var inputAngle: Angle { isRadians ? Angle(radians: inputNumber) : Angle(degrees: inputNumber) }

    private var content: some View {
        Group {
            if isInputMode {
                Button {
                    isInputMode = false
                    onDone(inputAngle)
                } label: { Image(systemName: "checkmark.circle") }
            }
            Image(systemName: "angle")
            if isInputMode {
                DecimalInput(title: isRadians ? "Radians" : "Degrees", inputNumber: $inputNumber)
            } else {
                Text(angleValue.formatted(decimalFormatStyle()))
            }
            Button {
                let angle = inputAngle
                isRadians.toggle()
                inputNumber = isRadians ? angle.radians : angle.degrees
            } label: { Text(isRadians ? "rad" : " ° ") }
        }
        .font(.callout.monospacedDigit())
    }
}
