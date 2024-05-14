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

// MARK: - axis, align, position

enum AxisAlign: CaseIterable {
    case start, center, end
}

extension AxisAlign: CustomStringConvertible {
    var description: String {
        switch self {
        case .start: "start"
        case .center: "center"
        case .end: "end"
        }
    }
}

enum PlaneAlign {
    case topLeading, topCenter, topTrailing
    case centerLeading, center, centerTrailing
    case bottomLeading, bottomCenter, bottomTrailing

    var isLeading: Bool { [.topLeading, .centerLeading, .bottomLeading].contains(self) }
    var isHorizontalCenter: Bool { [.topCenter, .center, .bottomCenter].contains(self) }
    var isTrailing: Bool { [.topTrailing, .centerTrailing, .bottomTrailing].contains(self) }

    var isTop: Bool { [.topLeading, .topCenter, .topTrailing].contains(self) }
    var isVerticalCenter: Bool { [.centerLeading, .center, .centerTrailing].contains(self) }
    var isBottom: Bool { [.bottomLeading, .bottomCenter, .bottomTrailing].contains(self) }

    func getAxisAlign(in axis: Axis) -> AxisAlign {
        switch axis {
        case .horizontal: isLeading ? .start : isTrailing ? .end : .center
        case .vertical: isTop ? .start : isBottom ? .end : .center
        }
    }

    init(horizontal: AxisAlign, vertical: AxisAlign) {
        switch (horizontal, vertical) {
        case (.start, .start): self = .topLeading
        case (.start, .center): self = .centerLeading
        case (.start, .end): self = .bottomLeading
        case (.center, .start): self = .topCenter
        case (.center, .center): self = .center
        case (.center, .end): self = .bottomCenter
        case (.end, .start): self = .topTrailing
        case (.end, .center): self = .centerTrailing
        case (.end, .end): self = .bottomTrailing
        }
    }
}

struct AtPlaneAlignModifier: ViewModifier {
    let position: PlaneAlign

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            if !position.isLeading { Spacer(minLength: 0) }
            VStack(spacing: 0) {
                if !position.isTop { Spacer(minLength: 0) }
                content
                if !position.isBottom { Spacer(minLength: 0) }
            }
            if !position.isTrailing { Spacer(minLength: 0) }
        }
    }
}

extension View {
    func atPlaneAlign(_ position: PlaneAlign) -> some View {
        modifier(AtPlaneAlignModifier(position: position))
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

// MARK: - ManagedScrollView

class ManagedScrollViewModel: ObservableObject {
    @Published fileprivate(set) var offset: Scalar = 0
    let coordinateSpaceName = UUID().uuidString

    var scrolled: Bool { offset > 0 }
}

fileprivate struct ScrollOffsetKey: PreferenceKey {
    typealias Value = Scalar
    static var defaultValue: Scalar = .zero
    static func reduce(value: inout Value, nextValue: () -> Value) { value += nextValue() }
}

fileprivate struct ScrollOffsetReaderModifier: ViewModifier {
    @ObservedObject var model: ManagedScrollViewModel

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(key: ScrollOffsetKey.self,
                                       value: -proxy.frame(in: .named(model.coordinateSpaceName)).origin.y)
            }
        )
    }
}

fileprivate struct ScrollOffsetSetterModifier: ViewModifier {
    @ObservedObject var model: ManagedScrollViewModel

    func body(content: Content) -> some View {
        content.coordinateSpace(name: model.coordinateSpaceName)
            .onPreferenceChange(ScrollOffsetKey.self) { value in withAnimation { model.offset = value } }
    }
}

fileprivate extension View {
    func scrollOffsetReader(model: ManagedScrollViewModel) -> some View {
        modifier(ScrollOffsetReaderModifier(model: model))
    }

    func scrollOffsetSetter(model: ManagedScrollViewModel) -> some View {
        modifier(ScrollOffsetSetterModifier(model: model))
    }
}

struct ManagedScrollView<Content: View>: View {
    @ObservedObject var model: ManagedScrollViewModel
    @ViewBuilder let content: (ScrollViewProxy) -> Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content(proxy)
                    .scrollOffsetReader(model: model)
            }
            .scrollOffsetSetter(model: model)
        }
    }
}

// MARK: - default colors

extension Color {
    // MARK: text

    static let lightText = Color(.lightText)
    static let darkText = Color(.darkText)
    static let placeholderText = Color(.placeholderText)

    // MARK: label

    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel = Color(.tertiaryLabel)
    static let quaternaryLabel = Color(.quaternaryLabel)

    // MARK: background

    static let systemBackground = Color(.systemBackground)
    static let secondarySystemBackground = Color(.secondarySystemBackground)
    static let tertiarySystemBackground = Color(.tertiarySystemBackground)

    // MARK: fill

    static let systemFill = Color(.systemFill)
    static let secondarySystemFill = Color(.secondarySystemFill)
    static let tertiarySystemFill = Color(.tertiarySystemFill)
    static let quaternarySystemFill = Color(.quaternarySystemFill)

    // MARK: grouped background

    static let systemGroupedBackground = Color(.systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(.secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground = Color(.tertiarySystemGroupedBackground)

    // MARK: gray

    static let systemGray = Color(.systemGray)
    static let systemGray2 = Color(.systemGray2)
    static let systemGray3 = Color(.systemGray3)
    static let systemGray4 = Color(.systemGray4)
    static let systemGray5 = Color(.systemGray5)
    static let systemGray6 = Color(.systemGray6)

    // MARK: others

    static let separator = Color(.separator)
    static let opaqueSeparator = Color(.opaqueSeparator)
    static let link = Color(.link)

    // MARK: system

    static let systemBlue = Color(.systemBlue)
    static let systemPurple = Color(.systemPurple)
    static let systemGreen = Color(.systemGreen)
    static let systemYellow = Color(.systemYellow)
    static let systemOrange = Color(.systemOrange)
    static let systemPink = Color(.systemPink)
    static let systemRed = Color(.systemRed)
    static let systemTeal = Color(.systemTeal)
    static let systemIndigo = Color(.systemIndigo)
}

extension Color {
    static let invisibleSolid: Color = .white.opacity(1e-3)
}

extension View {
    func invisibleSoildOverlay() -> some View {
        overlay(Color.invisibleSolid)
    }
}

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

// MARK: - BatchedPublished

@propertyWrapper
class _BatchedPublished<Instance: ObservableObject, Value> where Instance.ObjectWillChangePublisher == ObservableObjectPublisher {
    @available(*, unavailable)
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    var projectedValue: Published<Value>.Publisher {
        get { $value }
        set { $value = newValue }
    }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: KeyPath<Instance, Value>,
        storage storageKeyPath: KeyPath<Instance, _BatchedPublished>
    ) -> Value {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            if let updatingValue = wrapper.updatingValue {
                return updatingValue
            } else {
                return wrapper.value
            }
        }
        set {
            let wrapper = instance[keyPath: storageKeyPath]
            if wrapper.updatingValue == nil {
                wrapper.value = newValue
            } else {
                wrapper.updatingValue = newValue
            }
        }
    }

    var batchUpdater: (() -> Void) -> Void {
        { [weak self] update in
            guard let self else { return }
            if self.updatingValue != nil {
                update()
                return
            }
            self.updatingValue = self.value
            update()
            self.value = self.updatingValue!
            self.updatingValue = nil
        }
    }

    init(wrappedValue initialValue: Value) {
        value = initialValue
    }

    @Published private var value: Value

    private var updatingValue: Value?
}

extension ObservableObject where Self.ObjectWillChangePublisher == ObservableObjectPublisher {
    typealias BatchedPublished<T> = _BatchedPublished<Self, T>
}

// MARK: - TracedPublished

@propertyWrapper
class _TracedPublished<Instance: ObservableObject, Value> where Instance.ObjectWillChangePublisher == ObservableObjectPublisher {
    @available(*, unavailable)
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    var projectedValue: Published<Value>.Publisher {
        get { $value }
        set { $value = newValue }
    }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: KeyPath<Instance, Value>,
        storage storageKeyPath: KeyPath<Instance, _TracedPublished>
    ) -> Value {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            tracer.instant("get \(wrapper.message)")
            return wrapper.value
        }
        set {
            let wrapper = instance[keyPath: storageKeyPath]
            let _r = tracer.range("set \(wrapper.message)"); defer { _r() }
            tracer.range("objectWillChange") {
                instance.objectWillChange.send()
            }
            wrapper.value = newValue
        }
    }

    init(wrappedValue: Value, _ message: String) {
        value = wrappedValue
        self.message = message
    }

    @Published private var value: Value

    private var message: String
}

extension ObservableObject where Self.ObjectWillChangePublisher == ObservableObjectPublisher {
    typealias TracedPublished<T> = _TracedPublished<Self, T>
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

// MARK: - EquatableTuple

enum Monostate { case value }

extension Monostate: Equatable {}

extension Monostate: CustomStringConvertible {
    var description: String { "_" }
}

struct EquatableTuple<T0: Equatable, T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable, T5: Equatable>: Equatable {
    let v0: T0, v1: T1, v2: T2, v3: T3, v4: T4, v5: T5
    var tuple: (T0, T1, T2, T3, T4, T5) { (v0, v1, v2, v3, v4, v5) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.tuple == rhs.tuple }

    init(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3, _ v4: T4, _ v5: T5) {
        self.v0 = v0
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3
        self.v4 = v4
        self.v5 = v5
    }
}

extension EquatableTuple where T2 == Monostate, T3 == Monostate, T4 == Monostate, T5 == Monostate {
    init(_ v0: T0, _ v1: T1) { self.init(v0, v1, .value, .value, .value, .value) }
}

extension EquatableTuple where T3 == Monostate, T4 == Monostate, T5 == Monostate {
    init(_ v0: T0, _ v1: T1, _ v2: T2) { self.init(v0, v1, v2, .value, .value, .value) }
}

extension EquatableTuple where T4 == Monostate, T5 == Monostate {
    init(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3) { self.init(v0, v1, v2, v3, .value, .value) }
}

extension EquatableTuple where T5 == Monostate {
    init(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3, _ v4: T4) { self.init(v0, v1, v2, v3, v4, .value) }
}

// MARK: - Memorized

struct Memo<Key: Equatable, Content: View>: View, Equatable {
    let key: Key
    @ViewBuilder let content: () -> Content

    var body: some View { tracer.range("Memo") {
        content()
    } }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.key == rhs.key }
}

func memo<Key, Content>(_ key: Key, @ViewBuilder _ content: @escaping () -> Content) -> Memo<Key, Content> {
    .init(key: key, content: content)
}

func memo<T0, T1, T2, T3, T4, T5, Content>(
    deps: EquatableTuple<T0, T1, T2, T3, T4, T5>,
    @ViewBuilder _ content: @escaping () -> Content
) -> Memo<EquatableTuple<T0, T1, T2, T3, T4, T5>, Content> {
    .init(key: deps, content: content)
}

// MARK: - Selected

@propertyWrapper
struct Selected<Value: Equatable>: DynamicProperty {
    private class Storage: ObservableObject {
        var wrappedValue: Value {
            if let value {
                return value
            }
            setupSelectTask()
            return selector()
        }

        init(selector: @escaping () -> Value) {
            self.selector = selector
        }

        deinit {
            selectTask?.cancel()
        }

        private let selector: () -> Value
        private var value: Value?
        private var selectTask: Task<Void, Never>?

        private func setupSelectTask() {
            selectTask = Task { @MainActor [weak self] in
                self?.select()
            }
        }

        private func select() {
            withObservationTracking {
                let newValue = selector()
                if value != newValue {
                    objectWillChange.send()
                }
                value = newValue
            } onChange: { [weak self] in
                self?.setupSelectTask()
            }
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value { storage.wrappedValue }

    var projectedValue: Selected<Value> { self }

    init(wrappedValue: @autoclosure @escaping () -> Value) {
        _storage = StateObject(wrappedValue: Storage(selector: wrappedValue))
    }
}
