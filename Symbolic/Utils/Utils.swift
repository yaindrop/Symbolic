import Combine
import Foundation
import Observation
import SwiftUI

extension UUID: Identifiable {
    public var id: UUID { self }
}

// MARK: - SelfTransformable

protocol SelfTransformable {
    func apply<T>(_ transform: (Self) -> T) -> T
}

extension SelfTransformable {
    func apply<T>(_ transform: (Self) -> T) -> T { transform(self) }
}

// MARK: - Cloneable

protocol Cloneable {
    init(_: Self)
}

extension Cloneable {
    var cloned: Self { Self(self) }

    func with(_ transform: (inout Self) -> Void) -> Self {
        var cloned = cloned
        transform(&cloned)
        return cloned
    }
}

protocol TriviallyCloneable {}

extension TriviallyCloneable {
    init(_ v: Self) { self = v }
}

extension Array: Cloneable {}

extension UUID: Cloneable, TriviallyCloneable {}

// MARK: - ReflectedStringConvertible

public protocol ReflectedStringConvertible: CustomStringConvertible { }

extension ReflectedStringConvertible {
    public var description: String {
        let mirror = Mirror(reflecting: self)
        let propertiesStr = mirror.children.compactMap { label, value in
            guard let label = label else { return nil }
            return "\(label): \(value)"
        }.joined(separator: ", ")
        return "\(mirror.subjectType)(\(propertiesStr))"
    }
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

    var inertia: Vector2 { Vector2(predictedEndTranslation) - offset }
}

// MARK: - read size

struct ViewSizeReader: ViewModifier {
    let onChange: (CGSize) -> Void

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.size, initial: true) {
                        onChange(geometry.size)
                    }
                }
            }
    }
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        modifier(ViewSizeReader(onChange: onChange))
    }
}

// MARK: - Optional forSome

extension Optional {
    @inlinable public func forSome(_ callback: (Wrapped) -> Void) {
        if case let .some(v) = self {
            callback(v)
        }
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

// MARK: - Proxy

@propertyWrapper
struct _Proxy<Instance, Value> {
    let keyPath: ReferenceWritableKeyPath<Instance, Value>

    @available(*, unavailable, message: "@Proxy can only be applied to classes")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: KeyPath<Instance, Value>,
        storage storageKeyPath: KeyPath<Instance, Self>
    ) -> Value {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            return instance[keyPath: wrapper.keyPath]
        }
        set {
            let wrapper = instance[keyPath: storageKeyPath]
            instance[keyPath: wrapper.keyPath] = newValue
        }
    }

    init(_ keyPath: ReferenceWritableKeyPath<Instance, Value>) {
        self.keyPath = keyPath
    }
}

protocol EnableProxy {
    typealias Proxy<T> = _Proxy<Self, T>
}

// MARK: - CachedLazy

@propertyWrapper
struct _CachedLazy<Instance, Value> {
    var cached: Value?
    let computedKeyPath: KeyPath<Instance, Value>

    @available(*, unavailable, message: "@CachedLazy can only be applied to classes")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    @discardableResult
    mutating func refresh(_ instance: Instance) -> Value {
        let value = instance[keyPath: computedKeyPath]
        cached = value
        return value
    }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: ReferenceWritableKeyPath<Instance, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Instance, Self>
    ) -> Value {
        get {
            if let cached = instance[keyPath: storageKeyPath].cached {
                cached
            } else {
                instance[keyPath: storageKeyPath].refresh(instance)
            }
        }
        set {
            instance[keyPath: storageKeyPath].cached = newValue
        }
    }

    init(_ computedKeyPath: KeyPath<Instance, Value>) {
        self.computedKeyPath = computedKeyPath
    }
}

protocol EnableCachedLazy {
    typealias CachedLazy<T> = _CachedLazy<Self, T>
}

// MARK: - builder helper

func build<Content: View>(@ViewBuilder _ builder: () -> Content) -> Content { builder() }

func build<Content: ToolbarContent>(@ToolbarContentBuilder _ builder: () -> Content) -> Content { builder() }
