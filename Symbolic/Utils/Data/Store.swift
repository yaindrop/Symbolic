import Combine
import Foundation
import SwiftUI

private let storeTracer = tracer.tagged("store", enabled: true)
private let managerTracer = storeTracer.tagged("manager", enabled: true)
private let trackableTracer = storeTracer.tagged("trackable", enabled: true)
private let selectedTracer = storeTracer.tagged("selected", enabled: true)

private struct StoreSubscription {
    let id: Int
    let callback: () -> Void
}

// MARK: - StoreManager

private class StoreManager {
    private var subscriptionIdGen = IncrementalIdGenerator()
    private var idToSubscription: [Int: StoreSubscription] = [:]

    // MARK: tracking

    struct TrackingContext {
        var subscriptionId: Int
    }

    private(set) var tracking: TrackingContext?

    func withTracking<T>(_ apply: () -> T, onUpdate: @escaping () -> Void) -> (value: T, TrackingContext) {
        guard tracking == nil else {
            fatalError("Nested tracking of store properties is not supported.")
        }
        let id = subscriptionIdGen.generate()
        let _r = managerTracer.range("tracking \(id)"); defer { _r() }

        let tracking = TrackingContext(subscriptionId: id)
        self.tracking = tracking
        let result = apply()
        self.tracking = nil

        idToSubscription[id] = .init(id: id, callback: onUpdate)
        return (result, tracking)
    }

    func expire(subscriptionId: Int) {
        idToSubscription.removeValue(forKey: subscriptionId)
    }

    // MARK: updating

    class UpdatingContext: CancellableHolder {
        var cancellables = Set<AnyCancellable>()
        var subscriptions: [StoreSubscription] = []
        var willUpdateSubject = PassthroughSubject<Void, Never>()
    }

    private var updating: UpdatingContext?

    func withUpdating(_ apply: () -> Void) {
        if updating != nil {
            let _r = managerTracer.range("reenter updating"); defer { _r() }
            apply()
            return
        }
        let _r = managerTracer.range("updating"); defer { _r() }

        let updating = UpdatingContext()
        self.updating = updating
        apply()
        self.updating = nil

        notifyAll(updating)
    }

    func willUpdate(_ callback: @escaping () -> Void) {
        updating.forSome {
            $0.willUpdateSubject
                .sink(receiveValue: callback)
                .store(in: $0)
        }
    }

    func notify(subscriptionIds: Set<Int>) {
        let _r = managerTracer.range("notify"); defer { _r() }
        let activeSubscriptions = subscriptionIds.compactMap { idToSubscription.removeValue(forKey: $0) }
        updating.forSome {
            managerTracer.instant("append \(activeSubscriptions.map { $0.id })")
            $0.subscriptions += activeSubscriptions
        } else: {
            for subscription in activeSubscriptions {
                let _r = managerTracer.range("callback \(subscription.id)"); defer { _r() }
                subscription.callback()
            }
        }
    }

    private func notifyAll(_ context: UpdatingContext) {
        let _r = managerTracer.range("notifying all \(context.subscriptions.map { $0.id })"); defer { _r() }
        context.willUpdateSubject.send()
        for subscription in context.subscriptions {
            let _r = managerTracer.range("notifying \(subscription.id)"); defer { _r() }
            subscription.callback()
        }
    }

    // MARK: deriving

    class DerivingContext {
        var trackableIds: [Int] = []
        var publishers: [AnyPublisher<Void, Never>] = []
    }

    var deriving: DerivingContext?

    func withDeriving<T>(_ apply: () -> T) -> (value: T, DerivingContext) {
        guard deriving == nil else {
            fatalError("Nested deriving of store properties is not supported.")
        }
        let _r = managerTracer.range("deriving"); defer { _r() }

        let deriving = DerivingContext()
        self.deriving = deriving
        let result = apply()
        self.deriving = nil
        managerTracer.instant("trackableIds \(deriving.trackableIds)")

        return (result, deriving)
    }
}

private var _manager = StoreManager()
private var manager: StoreManager {
    get {
        assert(Thread.isMainThread, "Store manager can only be used on main thread.")
        return _manager
    }
    set {
        assert(Thread.isMainThread, "Store manager can only be used on main thread.")
        _manager = newValue
    }
}

// MARK: - Store

class Store: CancellableHolder {
    var cancellables = Set<AnyCancellable>()

    private var trackableIdGen = IncrementalIdGenerator()
    private var trackableIdToSubscriptionIds: [Int: Set<Int>] = [:]

    fileprivate func generateTrackableId() -> Int { trackableIdGen.generate() }

    fileprivate func onTrack(of trackableId: Int, in subscriptionId: Int) {
        let _r = storeTracer.range("on track of \(trackableId) in subscription \(subscriptionId)"); defer { _r() }
        var ids = trackableIdToSubscriptionIds[trackableId] ?? []
        ids.insert(subscriptionId)
        trackableIdToSubscriptionIds[trackableId] = ids
    }

    fileprivate func onChange(of trackableId: Int) -> Set<Int> {
        let subscriptionIds = trackableIdToSubscriptionIds.removeValue(forKey: trackableId)
        let _r = storeTracer.range("on change of \(trackableId), \(subscriptionIds.map { "with \($0.count) subscriptions" } ?? "without subscription")"); defer { _r() }
        guard let subscriptionIds else { return [] }
        return subscriptionIds
    }
}

// MARK: - Trackable

@propertyWrapper
struct _Trackable<Instance: _StoreProtocol, Value: Equatable> {
    fileprivate var id: Int?
    fileprivate var value: Value
    fileprivate let didSetSubject = PassthroughSubject<Value, Never>()
    fileprivate let willUpdateSubject = PassthroughSubject<Value, Never>()

    @available(*, unavailable, message: "@Trackable can only be applied to Store")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    struct Projected {
        let didSet: AnyPublisher<Value, Never>
        let willUpdate: AnyPublisher<Value, Never>
    }

    var projectedValue: Projected { .init(didSet: didSetSubject.eraseToAnyPublisher(), willUpdate: willUpdateSubject.eraseToAnyPublisher()) }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: ReferenceWritableKeyPath<Instance, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Instance, Self>
    ) -> Value {
        get { instance.access(keypath: storageKeyPath) }
        @available(*, unavailable) set {}
    }

    init(wrappedValue: Value) {
        value = wrappedValue
    }
}

// MARK: - Derived

@propertyWrapper
struct _Derived<Instance: _StoreProtocol, Value: Equatable> {
    fileprivate class Storage: CancellableHolder {
        var value: Value
        var derive: (() -> Value)?

        var trackableIds: [Int] = []
        let willUpdateSubject = PassthroughSubject<Value, Never>()

        var cancellables = Set<AnyCancellable>()

        init(value: Value) {
            self.value = value
        }

        func update() {
            let _r = trackableTracer.range("update derived"); defer { _r() }
            guard let derive else { return }
            let (value, context) = manager.withDeriving(derive)

            self.value = value
            willUpdateSubject.send(value)

            trackableIds = context.trackableIds
            cancellables.removeAll()
            for publisher in context.publishers {
                publisher
                    .sink { self.update() }
                    .store(in: self)
            }
        }
    }

    fileprivate let storage: Storage

    @available(*, unavailable, message: "@Derived can only be applied to Store")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    struct Projected {
        let willUpdate: AnyPublisher<Value, Never>
    }

    var projectedValue: Projected { .init(willUpdate: storage.willUpdateSubject.eraseToAnyPublisher()) }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: ReferenceWritableKeyPath<Instance, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Instance, Self>
    ) -> Value {
        get { instance.access(keypath: storageKeyPath) }
        @available(*, unavailable) set {}
    }

    // setup
    func callAsFunction(derive: @escaping () -> Value) {
        guard storage.derive == nil else { return }
        storage.derive = derive
        storage.update()
    }

    init(wrappedValue: Value) {
        storage = .init(value: wrappedValue)
    }
}

// MARK: - StoreProtocol

protocol _StoreProtocol: Store {
    typealias Trackable<T: Equatable> = _Trackable<Self, T>
    typealias Derived<T: Equatable> = _Derived<Self, T>
}

extension Store: _StoreProtocol {
    struct Updater<S: _StoreProtocol> {
        let store: S

        func callAsFunction<T: Equatable>(_ keypath: ReferenceWritableKeyPath<S, S.Trackable<T>>, _ value: T) {
            store.update(keypath, value)
        }

        fileprivate init(_ store: S) {
            self.store = store
        }
    }
}

extension _StoreProtocol {
    fileprivate func access<T>(keypath: ReferenceWritableKeyPath<Self, Trackable<T>>) -> T {
        let _r = trackableTracer.range("access \(keypath)"); defer { _r() }
        @Ref(self, keypath) var wrapper
        let id: Int
        if let wrapperId = wrapper.id {
            id = wrapperId
        } else {
            id = generateTrackableId()
            wrapper.id = id
        }
        if let tracking = manager.tracking {
            onTrack(of: id, in: tracking.subscriptionId)
        }
        if let deriving = manager.deriving {
            deriving.trackableIds.append(id)
            deriving.publishers.append(wrapper.willUpdateSubject.map { _ in () }.eraseToAnyPublisher())
        }
        return wrapper.value
    }

    fileprivate func access<T>(keypath: ReferenceWritableKeyPath<Self, Derived<T>>) -> T {
        let _r = trackableTracer.range("access \(keypath)"); defer { _r() }
        @Ref(self, keypath) var wrapper
        let storage = wrapper.storage
        if let tracking = manager.tracking {
            for id in storage.trackableIds {
                onTrack(of: id, in: tracking.subscriptionId)
            }
        }
        if let deriving = manager.deriving {
            deriving.trackableIds += storage.trackableIds
            deriving.publishers.append(storage.willUpdateSubject.map { _ in () }.eraseToAnyPublisher())
        }
        return storage.value
    }

    fileprivate func update<T>(_ keypath: ReferenceWritableKeyPath<Self, Trackable<T>>, _ newValue: T) {
        let _r = trackableTracer.range("update \(keypath) with \(newValue)"); defer { _r() }
        @Ref(self, keypath) var wrapper
        let id: Int
        if let wrapperId = wrapper.id {
            id = wrapperId
        } else {
            id = generateTrackableId()
            wrapper.id = id
        }
        guard wrapper.value != newValue else { return }
        wrapper.value = newValue
        wrapper.didSetSubject.send(newValue)

        manager.notify(subscriptionIds: onChange(of: id))
        manager.willUpdate {
            wrapper.willUpdateSubject.send(wrapper.value)
        }
    }

    func update(_ callback: (Updater<Self>) -> Void) {
        manager.withUpdating {
            callback(Updater(self))
        }
    }
}

func withStoreUpdating(_ apply: () -> Void) {
    manager.withUpdating(apply)
}

// MARK: - SelectedStorage

class SelectedStorage<Value: Equatable>: ObservableObject {
    private(set) var name: String?
    private var _value: Value?
    private var subscriptionId: Int?
    private var updateTask: Task<Void, Never>?

    // value must have been assigned after track in init
    var value: Value { _value! }

    init(name: String? = nil) {
        self.name = name
        track()
    }

    deinit {
        updateTask?.cancel()
    }

    func select() -> Value { fatalError("Not implemented") }

    func track() {
        let _r = selectedTracer.range(name.map { "select \($0)" } ?? "select"); defer { _r() }
        if let subscriptionId {
            manager.expire(subscriptionId: subscriptionId)
        }
        let (newValue, context) = manager.withTracking { select() } onUpdate: { [weak self] in self?.track() }
        subscriptionId = context.subscriptionId
        if _value != newValue {
            _value = newValue
            setupUpdateTask()
            selectedTracer.instant("updated")
        }
    }

    private func setupUpdateTask() {
        updateTask?.cancel()
        updateTask = Task { @MainActor in self.objectWillChange.send() }
    }
}

// MARK: - Selected

@propertyWrapper
struct Selected<Value: Equatable>: DynamicProperty {
    private class Storage: SelectedStorage<Value> {
        var selector: () -> Value

        init(selector: @escaping () -> Value, name: String? = nil) {
            self.selector = selector
            super.init(name: name)
        }

        override func select() -> Value {
            selector()
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value { storage.value }

    // reselect
    func callAsFunction(_ selector: @escaping () -> Value) {
        storage.selector = selector
        storage.track()
    }

    init(_ selector: @escaping () -> Value, _ name: String? = nil) {
        _storage = StateObject(wrappedValue: Storage(selector: selector, name: name))
    }

    init(wrappedValue: @autoclosure @escaping () -> Value, _ name: String? = nil) {
        self.init(wrappedValue, name)
    }
}

// MARK: - Computed

@propertyWrapper
struct Computed<Input, Value: Equatable>: DynamicProperty {
    private class Storage: SelectedStorage<Value> {
        var defaultValue: Value
        var compute: (Input) -> Value
        var input: Input?

        init(defaultValue: Value, name: String? = nil, compute: @escaping (Input) -> Value) {
            self.defaultValue = defaultValue
            self.compute = compute
            super.init(name: name)
        }

        override func select() -> Value {
            input.map { compute($0) } ?? defaultValue
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value { storage.value }

    // setup
    func callAsFunction(_ input: Input) {
        storage.input = input
        storage.track()
    }

    init(wrappedValue: Value, _ name: String, _ compute: @escaping (Input) -> Value) {
        _storage = StateObject(wrappedValue: Storage(defaultValue: wrappedValue, name: name, compute: compute))
    }

    init(wrappedValue: Value, _ compute: @escaping (Input) -> Value) {
        _storage = StateObject(wrappedValue: Storage(defaultValue: wrappedValue, name: nil, compute: compute))
    }
}

extension View {
    func compute<Input: Equatable, Value: Equatable>(_ wrapper: Computed<Input, Value>, _ input: Input) -> some View {
        onChange(of: input, initial: true) { wrapper(input) }
    }

    func compute<T0: Equatable, T1: Equatable, Value: Equatable>(_ wrapper: Computed<(T0, T1), Value>, _ input: (T0, T1)) -> some View {
        onChange(of: EquatableTuple.init <- input, initial: true) { wrapper(input) }
    }

    func compute<T0: Equatable, T1: Equatable, T2: Equatable, Value: Equatable>(_ wrapper: Computed<(T0, T1, T2), Value>, _ input: (T0, T1, T2)) -> some View {
        onChange(of: EquatableTuple.init <- input, initial: true) { wrapper(input) }
    }

    func compute<T0: Equatable, T1: Equatable, T2: Equatable, T3: Equatable, Value: Equatable>(_ wrapper: Computed<(T0, T1, T2, T3), Value>, _ input: (T0, T1, T2, T3)) -> some View {
        onChange(of: EquatableTuple.init <- input, initial: true) { wrapper(input) }
    }

    func compute<T0: Equatable, T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable, Value: Equatable>(_ wrapper: Computed<(T0, T1, T2, T3, T4), Value>, _ input: (T0, T1, T2, T3, T4)) -> some View {
        onChange(of: EquatableTuple.init <- input, initial: true) { wrapper(input) }
    }

    func compute<T0: Equatable, T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable, T5: Equatable, Value: Equatable>(_ wrapper: Computed<(T0, T1, T2, T3, T4, T5), Value>, _ input: (T0, T1, T2, T3, T4, T5)) -> some View {
        onChange(of: EquatableTuple.init <- input, initial: true) { wrapper(input) }
    }
}
