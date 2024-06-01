import Combine
import Foundation
import Observation
import SwiftUI

extension UUID: Identifiable {
    public var id: UUID { self }
}

extension Optional {
    func map<U>(_ then: (Wrapped) throws -> U?) rethrows -> U? {
        if case let .some(v) = self {
            return try then(v)
        }
        return nil
    }

    mutating func forSome(_ then: (inout Wrapped) throws -> Void, else: (() throws -> Void)? = nil) rethrows {
        if case .some = self {
            try then(&self!)
        } else {
            try `else`?()
        }
    }
}

class IncrementalIdGenerator {
    func generate() -> Int {
        let id = next
        next += 1
        return id
    }

    private var next: Int = 0
}

// MARK: - tuple applying

func apply<Input, Output>(_ function: (Input) -> Output, _ tuple: Input) -> Output {
    function(tuple)
}

precedencegroup TupleApplyingPrecedence {
    higherThan: CastingPrecedence
    lowerThan: RangeFormationPrecedence
    associativity: left
}

infix operator <-: TupleApplyingPrecedence
func <- <Input, Output>(function: (Input) -> Output, tuple: Input) -> Output {
    apply(function, tuple)
}

// MARK: - ClosedRange

extension ClosedRange {
    func clamp(_ value: Bound) -> Bound {
        lowerBound > value ? lowerBound : upperBound < value ? upperBound : value
    }

    init(start: Bound, end: Bound) { self = start < end ? start ... end : end ... start }
}

// MARK: - conditional modifier

extension View {
    @ViewBuilder func `if`<Value, T: View>(
        _ value: @autoclosure () -> Value?,
        then content: (Self, Value) -> T
    ) -> some View {
        if let value = value() {
            content(self, value)
        } else {
            self
        }
    }

    @ViewBuilder func `if`<Value, Content: View, NilContent: View>(
        _ value: @autoclosure () -> Value?,
        then content: (Self, Value) -> Content,
        else nilContent: (Self) -> NilContent
    ) -> some View {
        if let value = value() {
            content(self, value)
        } else {
            nilContent(self)
        }
    }

    @ViewBuilder func `if`<T: View>(
        _ condition: @autoclosure () -> Bool,
        then content: (Self) -> T
    ) -> some View {
        if condition() {
            content(self)
        } else {
            self
        }
    }

    @ViewBuilder func `if`<TrueContent: View, FalseContent: View>(
        _ condition: @autoclosure () -> Bool,
        then trueContent: (Self) -> TrueContent,
        else falseContent: (Self) -> FalseContent
    ) -> some View {
        if condition() {
            trueContent(self)
        } else {
            falseContent(self)
        }
    }

    func modifier(_ modifier: (some ViewModifier)?) -> some View {
        self.if(modifier != nil, then: { $0.modifier(modifier!) })
    }
}

// MARK: - invisible solid

extension Color {
    static let invisibleSolid: Color = .white.opacity(1e-3)
}

extension View {
    func invisibleSoildOverlay() -> some View {
        overlay(Color.invisibleSolid)
    }
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

extension Dictionary {
    func value(key: Key) -> Value? { self[key] }

    mutating func getOrSetDefault(key: Key, _ defaultValue: @autoclosure () -> Value) -> Value {
        if let value = self[key] {
            return value
        }
        let value = defaultValue()
        self[key] = value
        return value
    }
}

extension Array where Element: Hashable {
    func intersection(_ other: Self) -> Set<Element> {
        Set(self).intersection(other)
    }

    func subtracting(_ other: Self) -> Self {
        let intersection = self.intersection(other)
        return filter { intersection.contains($0) }
    }
}
