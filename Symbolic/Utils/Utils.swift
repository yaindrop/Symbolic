import Combine
import Foundation
import Observation
import SwiftUI

extension UUID: Identifiable {
    public var id: UUID { self }
}

extension Optional {
    func forSome(_ callback: (Wrapped) -> Void) {
        if case let .some(v) = self {
            callback(v)
        }
    }
}

func setIfChanged<T: Equatable>(_ value: inout T, _ newValue: T) {
    if value != newValue {
        value = newValue
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
        return lowerBound > value ? lowerBound : upperBound < value ? upperBound : value
    }

    init(start: Bound, end: Bound) { self = start < end ? start ... end : end ... start }
}

// MARK: - conditional modifier

extension View {
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

// MARK: - Gesture

extension Gesture {
    @inlinable public func updating(flag: GestureState<Bool>) -> GestureStateGesture<Self, Bool> {
        updating(flag) { _, state, _ in state = true }
    }
}

extension DragGesture.Value {
    var offset: Vector2 { .init(translation) }

    var speed: Vector2 { .init(velocity) }
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
