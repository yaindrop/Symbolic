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
