import Combine
import SwiftUI

// MARK: - Configs

extension Numpad {
    struct Configs {
        var range: ClosedRange<Double>?
        var maxDecimalLength: Int?

        fileprivate func validate(_ decomposed: Decomposed) -> Warning? {
            guard let value = Double(decomposed.composed) else { return .unknown }
            if let range {
                guard range.contains(value) else { return .range(range) }
            }
            if let maxDecimalLength {
                guard decomposed.decimal?.count ?? 0 <= maxDecimalLength else { return .maxDecimalLength(maxDecimalLength) }
            }
            return nil
        }
    }

    fileprivate enum Warning: Equatable {
        case unknown, range(ClosedRange<Double>), maxDecimalLength(Int)

        var message: String {
            switch self {
            case .unknown: "Invalid input"
            case let .range(v): "Range is \(v.lowerBound) to \(v.upperBound)"
            case let .maxDecimalLength(v): "Max \(v) decimals"
            }
        }
    }
}

// MARK: - KeyKind

private extension Numpad {
    enum KeyKind {
        case number(Int)
        case dot
        case delete
        case negate
        case done
    }
}

// MARK: - Model

private extension Numpad {
    struct Decomposed: Equatable {
        var negated: Bool = false
        var integer: String = "0"
        var decimal: String?

        var composed: String { "\(negated ? "-" : "")\(integer)\(decimal.map { ".\($0)" } ?? "")" }
    }

    class Model: ObservableObject {
        let configs: Configs
        @Published var decomposed = Decomposed()
        @Published var lastWarning: Warning?

        var negated: Bool { decomposed.negated }

        var integer: String { decomposed.integer }

        var decimal: String? { decomposed.decimal }

        var value: Double? { .init(decomposed.composed) }

        var displayValue: String {
            var formatted = value!.formatted(FloatingPointFormatStyle())
            if let decimal, decimal.allSatisfy({ $0 == "0" }) {
                formatted += ".\(decimal)"
            }
            return formatted
        }

        func onKey(_ kind: Numpad.KeyKind) {
            var tmp = decomposed
            switch kind {
            case let .number(n):
                if let decimal = decimal {
                    tmp.decimal = decimal + "\(n)"
                } else if integer == "0" {
                    tmp.integer = "\(n)"
                } else {
                    tmp.integer += "\(n)"
                }
            case .dot:
                if decimal == nil {
                    tmp.decimal = ""
                }
            case .delete:
                if let decimal = decimal {
                    if decimal.isEmpty {
                        tmp.decimal = nil
                    } else {
                        tmp.decimal = .init(decimal.dropLast())
                    }
                } else {
                    if integer == "0" && negated {
                        tmp.negated = false
                    } else if integer.count == 1 {
                        tmp.integer = "0"
                    } else {
                        tmp.integer = .init(integer.dropLast())
                    }
                }
            case .negate:
                tmp.negated.toggle()
            case .done:
                break
            }
            if let warning = configs.validate(tmp) {
                lastWarning = warning
            } else {
                decomposed = tmp
                lastWarning = nil
            }
        }

        init(configs: Configs) {
            self.configs = configs
        }
    }
}

// MARK: - Numpad

struct Numpad: View {
    @StateObject private var model = Model(configs: .init(range: -1000 ... 2000, maxDecimalLength: 555))

    var body: some View {
        content
            .environmentObject(model)
    }
}

// MARK: private

private extension Numpad {
    var size: CGSize { .init(200, 200) }

    var content: some View {
        VStack(spacing: 0) {
            Display()
                .frame(height: size.height / 4)
            input
                .frame(height: size.height * 3 / 4)
        }
        .background(.ultraThinMaterial)
        .frame(size: size)
        .clipRounded(radius: 6)
    }

    var input: some View {
        HStack(spacing: 0) {
            numbers
                .padding(.trailing, 2)
                .frame(width: size.width * 3 / 4)
            controls
                .frame(width: size.width / 4)
        }
    }

    var numbers: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Key(kind: .number(7))
                Key(kind: .number(8))
                Key(kind: .number(9))
            }
            HStack(spacing: 0) {
                Key(kind: .number(4))
                Key(kind: .number(5))
                Key(kind: .number(6))
            }
            HStack(spacing: 0) {
                Key(kind: .number(1))
                Key(kind: .number(2))
                Key(kind: .number(3))
            }
            HStack(spacing: 0) {
                Key(kind: .dot)
                Key(kind: .number(0))
                Key(kind: .delete)
            }
        }
    }

    var controls: some View {
        VStack(spacing: 0) {
            Key(kind: .negate)
            Key(kind: .done)
        }
    }
}

// MARK: - Display

private extension Numpad {
    struct Display: View {
        @EnvironmentObject var model: Model

        @AutoResetState(configs: .init(duration: 2)) private var activeWarning: Warning?
        @State private var shaking: Bool = false

        var body: some View {
            content
                .animation(.normal, value: activeWarning)
                .onReceive(model.$lastWarning) { warning in
                    if let warning {
                        activeWarning = warning
                        shaking = true
                        withAnimation(Animation.spring(response: 0.2, dampingFraction: 0.2, blendDuration: 0.2)) {
                            shaking = false
                        }
                    }
                }
        }
    }
}

// MARK: private

private extension Numpad.Display {
    var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(model.displayValue)
                    .font(.body)
                    .offset(y: shaking ? 3 : 0)
                    .padding(.horizontal, 12)
                Spacer()
            }
            .frame(maxHeight: .infinity)
            if let activeWarning {
                Text(activeWarning.message)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Key

private extension Numpad {
    struct Key: View {
        @EnvironmentObject var model: Model

        var kind: KeyKind

        @State private var down: Bool = false

        var body: some View {
            content
        }
    }
}

// MARK: private

private extension Numpad.Key {
    var content: some View {
        Rectangle()
            .fill(.regularMaterial)
            .padding(1)
            .overlay { label }
            .scaleEffect(down ? 0.8 : 1)
            .animation(.fast, value: down)
            .multipleGesture(disabled ? nil : .init(
                onPress: { _ in down = true },
                onPressEnd: { _, _ in down = false },
                onTap: { _ in model.onKey(kind) }
            ))
            .opacity(disabled ? 0.5 : 1)
    }

    @ViewBuilder var label: some View {
        switch kind {
        case let .number(n):
            Text("\(n)")
        case .dot:
            Text(".")
        case .delete:
            Image(systemName: "delete.backward")
        case .negate:
            Image(systemName: "plusminus")
        case .done:
            Image(systemName: "checkmark.circle")
        }
    }

    var disabled: Bool {
        switch kind {
        case .number: false
        case .dot: model.configs.maxDecimalLength.map { $0 <= 0 } ?? false
        case .delete: false
        case .negate: model.configs.range.map { $0.lowerBound >= 0 } ?? false
        case .done: false
        }
    }
}
