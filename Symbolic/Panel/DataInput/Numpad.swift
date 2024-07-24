import Combine
import SwiftUI

// MARK: - Configs

extension Numpad {
    struct Configs {
        var label: String?
        var range: ClosedRange<Double>
        var maxDecimalLength: Int

        init(label: String? = nil, range: ClosedRange<Double> = -1e6 ... 1e6, maxDecimalLength: Int = 3) {
            self.label = label
            self.range = range
            self.maxDecimalLength = (0 ... 6).clamp(maxDecimalLength)
        }
    }
}

private extension Numpad.Configs {
    func validate(_ decomposed: Numpad.Decomposed) -> Numpad.Warning? {
        guard let value = Double(decomposed.composed) else { return .unknown }
        guard range.contains(value) else { return .range(range) }
        guard decomposed.decimal?.count ?? 0 <= maxDecimalLength else { return .maxDecimalLength(maxDecimalLength) }
        return nil
    }
}

// MARK: - KeyKind

private extension Numpad {
    enum Warning: Equatable {
        case unknown
        case range(ClosedRange<Double>)
        case maxDecimalLength(Int)

        var message: String {
            switch self {
            case .unknown: "Invalid input"
            case let .range(v): "Range is \(v.lowerBound) to \(v.upperBound)"
            case let .maxDecimalLength(v): "Max \(v) decimals"
            }
        }
    }

    enum KeyKind {
        case number(Int)
        case dot
        case delete
        case negate
        case done
    }
}

// MARK: - Decomposed

private extension Numpad {
    struct Decomposed: Equatable {
        var negated: Bool = false
        var integer: String = "0"
        var decimal: String?

        var composed: String { "\(negated ? "-" : "")\(integer)\(decimal.map { ".\($0)" } ?? "")" }

        init(negated: Bool, integer: String, decimal: String?) {
            self.negated = negated
            self.integer = integer
            self.decimal = decimal
        }

        init(value: Double, configs: Configs) {
            negated = value < 0

            let value = configs.range.clamp(value)
            let absValue = abs(value)
            let integerValue = floor(absValue)
            integer = "\(Int(integerValue))"

            let decimalValue = absValue - integerValue
            let decimalDigits = round(decimalValue * pow(10, Double(configs.maxDecimalLength)))
            let decimalString = "\(Int(decimalDigits))"
            let leadingZeros = String(repeating: "0", count: configs.maxDecimalLength - decimalString.count)
            let zeroTrimmed = decimalString.trimmingCharacters(in: .init(charactersIn: "0"))
            decimal = leadingZeros + zeroTrimmed
        }
    }
}

// MARK: - Model

private extension Numpad {
    class Model: ObservableObject {
        let configs: Configs

        @Published var decomposed: Decomposed

        private let doneSubject = PassthroughSubject<Void, Never>()
        private let warningSubject = PassthroughSubject<Warning?, Never>()

        init(initialValue: Double, configs: Configs) {
            self.configs = configs
            decomposed = .init(value: initialValue, configs: configs)
        }
    }
}

// MARK: private

private extension Numpad.Model {
    var donePublisher: AnyPublisher<Void, Never> { doneSubject.eraseToAnyPublisher() }
    var warningPublisher: AnyPublisher<Numpad.Warning?, Never> { warningSubject.eraseToAnyPublisher() }

    var negated: Bool { decomposed.negated }

    var integer: String { decomposed.integer }

    var decimal: String? { decomposed.decimal }

    var value: Double? { .init(decomposed.composed) }

    var displayValue: String {
        guard let value else { return "NaN" }
        let formatted = value.formatted(FloatingPointFormatStyle())
        guard let decimal else { return formatted }

        let arr = Array(decimal)
        let lastNonZeroIndex = arr.lastIndex { $0 != "0" }
        guard let lastNonZeroIndex else { return formatted + ".\(decimal)" }

        guard lastNonZeroIndex != arr.count - 1 else { return formatted }

        let zerosCount = arr.count - 1 - lastNonZeroIndex
        return formatted + .init(repeating: "0", count: zerosCount)
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
            doneSubject.send()
            return
        }
        let warning = configs.validate(tmp)
        warningSubject.send(warning)
        if warning == nil {
            decomposed = tmp
        }
    }
}

// MARK: - Numpad

struct Numpad: View {
    let configs: Configs
    let onChange: ((Double) -> Void)?
    let onDone: ((Double) -> Void)?

    @StateObject private var model: Model

    init(initialValue: Double, configs: Configs = .init(), onChange: ((Double) -> Void)? = nil, onDone: ((Double) -> Void)? = nil) {
        self.configs = configs
        self.onChange = onChange
        self.onDone = onDone
        _model = .init(wrappedValue: .init(initialValue: initialValue, configs: configs))
    }

    var body: some View {
        content
            .environmentObject(model)
            .onChange(of: model.value) {
                guard let v = model.value else { return }
                onChange?(v)
            }
            .onReceive(model.donePublisher) {
                guard let v = model.value else { return }
                onDone?(v)
            }
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
                .onReceive(model.warningPublisher) { warning in
                    activeWarning = warning
                    if warning != nil {
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
                if let label = model.configs.label {
                    Text("\(label)=")
                        .font(.callout.monospaced())
                        .opacity(0.5)
                }
                Text(model.displayValue)
                    .font(.body)
                    .offset(y: shaking ? 3 : 0)
                Spacer()
            }
            .padding(.horizontal, 12)
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
            .clipRounded(radius: 6)
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
        case .dot: model.configs.maxDecimalLength <= 0
        case .delete: false
        case .negate: model.configs.range.lowerBound >= 0
        case .done: false
        }
    }
}

// MARK: - NumpadPortal

struct NumpadPortal: View {
    @Environment(\.portalId) var portalId

    let initialValue: Double
    var configs: Numpad.Configs = .init()
    var onChange: ((Double) -> Void)?
    var onDone: ((Double) -> Void)?

    var body: some View {
        Numpad(initialValue: initialValue, configs: configs, onChange: onChange, onDone: {
            onDone?($0)
            global.portal.deregister(id: portalId)
        })
    }
}
