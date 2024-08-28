import SwiftUI

// MARK: - pair

struct Pair<T0, T1> { let first: T0, second: T1 }

extension Pair: Equatable, EquatableBy where T0: Equatable, T1: Equatable {
    var equatableBy: some Equatable { first; second }
}

// MARK: - readable time

extension TimeInterval {
    var readableTime: String {
        if self < 1e-6 {
            String(format: "%.1f ns", self / 1e-9)
        } else if self < 1e-3 {
            String(format: "%.1f us", self / 1e-6)
        } else if self < 1 {
            String(format: "%.1f ms", self / 1e-3)
        } else if self < 60 {
            String(format: "%.1 fs", self)
        } else if self < 60 * 60 {
            String(format: "%.1f min", self / 60)
        } else if self < 60 * 60 * 24 {
            String(format: "%.1f hr", self / 60 / 60)
        } else {
            String(format: "%.1f days", self / 60 / 60 / 24)
        }
    }
}

extension Duration {
    var readable: String {
        let (seconds, attoseconds) = components
        if seconds > 0 {
            if seconds < 60 {
                return String(format: "%d s", seconds)
            } else if seconds < 60 * 60 {
                return String(format: "%.1f min", Double(seconds) / 60)
            } else if seconds < 60 * 60 * 24 {
                return String(format: "%.1f hr", Double(seconds) / 60 / 60)
            } else {
                return String(format: "%.1f days", Double(seconds) / 60 / 60 / 24)
            }
        } else {
            if attoseconds < Int(1e9) {
                return "< 1 ns"
            } else if attoseconds < Int(1e12) {
                return String(format: "%.1f ns", Double(attoseconds) / 1e9)
            } else if attoseconds < Int(1e15) {
                return String(format: "%.1f us", Double(attoseconds) / 1e12)
            } else {
                return String(format: "%.1f ms", Double(attoseconds) / 1e15)
            }
        }
    }
}

// MARK: - modify

func modify<T>(_ value: T, _ modifier: (inout T) -> Void) -> T {
    var value = value
    modifier(&value)
    return value
}

func withAssigned<T, Value, Result>(_ instance: T, _ keyPath: ReferenceWritableKeyPath<T, Value?>, _ value: Value, _ work: () -> Result) -> Result {
    @Ref(instance, keyPath) var ref
    ref = value
    let result = work()
    ref = nil
    return result
}

func withLast<T, Value, Result>(_ instance: T, _ keyPath: ReferenceWritableKeyPath<T, [Value]>, _ value: Value, _ work: () -> Result) -> Result {
    @Ref(instance, keyPath) var ref
    ref.append(value)
    let result = work()
    ref.removeLast()
    return result
}

// MARK: - builder helper

func build<Content: View>(@ViewBuilder _ builder: () -> Content) -> Content { builder() }

func build<Content: ToolbarContent>(@ToolbarContentBuilder _ builder: () -> Content) -> Content { builder() }

// MARK: - Binding

extension Binding {
    init<T>(_ instance: T, _ keyPath: ReferenceWritableKeyPath<T, Value>) {
        self.init(get: { instance[keyPath: keyPath] }, set: { instance[keyPath: keyPath] = $0 })
    }
}

extension Binding where Value: Equatable {
    func predicate(_ trueValue: Value, _ falseValue: Value) -> Binding<Bool> {
        Binding<Bool>(get: {
            wrappedValue == trueValue
        }, set: { newValue in
            if wrappedValue != trueValue, newValue {
                wrappedValue = trueValue
            } else if wrappedValue == trueValue, !newValue {
                wrappedValue = falseValue
            }
        })
    }
}

// MARK: - Task

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds duration: Double) async throws {
        try await Task.sleep(nanoseconds: .init(duration * Double(NSEC_PER_SEC)))
    }
}

extension Task where Success == Void, Failure == Never {
    static func delayed(seconds duration: Double, work: @escaping () async -> Void) -> Self {
        .init {
            try? await Task<Never, Never>.sleep(seconds: duration)
            guard !Task<Never, Never>.isCancelled else { return }
            await work()
        }
    }
}

// MARK: - UInt64

extension UInt64 {
    init(littleEndian b0: UInt8, _ b1: UInt8 = 0, _ b2: UInt8 = 0, _ b3: UInt8 = 0, _ b4: UInt8 = 0, _ b5: UInt8 = 0, _ b6: UInt8 = 0, _ b7: UInt8 = 0) {
        self = Self(b0)
            | Self(b1) << 8
            | Self(b2) << 16
            | Self(b3) << 24
            | Self(b4) << 32
            | Self(b5) << 40
            | Self(b6) << 48
            | Self(b7) << 56
    }

    init(bigEndian b0: UInt8, _ b1: UInt8 = 0, _ b2: UInt8 = 0, _ b3: UInt8 = 0, _ b4: UInt8 = 0, _ b5: UInt8 = 0, _ b6: UInt8 = 0, _ b7: UInt8 = 0) {
        self = Self(b7)
            | Self(b6) << 8
            | Self(b5) << 16
            | Self(b4) << 24
            | Self(b3) << 32
            | Self(b2) << 40
            | Self(b1) << 48
            | Self(b0) << 56
    }
}

// MARK: - Codable

extension Angle: Codable {
    public init(from decoder: any Decoder) throws {
        try self.init(radians: decoder.singleValueContainer().decode(Double.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(radians)
    }
}

struct CodableColor: Equatable, Codable {
    var cgColor: CGColor

    init(cgColor: CGColor) {
        self.cgColor = cgColor
    }

    init(uiColor: UIColor) {
        cgColor = uiColor.cgColor
    }

    enum CodingKeys: String, CodingKey {
        case colorSpace
        case components
    }

    init(from decoder: Decoder) throws {
        let container = try decoder
            .container(keyedBy: CodingKeys.self)
        let colorSpace = try container
            .decode(String.self, forKey: .colorSpace)
        let components = try container
            .decode([CGFloat].self, forKey: .components)
        guard let cgColorSpace = CGColorSpace(name: colorSpace as CFString),
              let cgColor = CGColor(colorSpace: cgColorSpace, components: components) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "")) }
        self.cgColor = cgColor
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard let colorSpace = cgColor.colorSpace?.name,
              let components = cgColor.components else { throw EncodingError.invalidValue(cgColor, .init(codingPath: encoder.codingPath, debugDescription: "")) }
        try container.encode(colorSpace as String, forKey: .colorSpace)
        try container.encode(components, forKey: .components)
    }
}
