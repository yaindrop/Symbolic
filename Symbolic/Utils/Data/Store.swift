import Combine
import Foundation
import SwiftUI

private let storeTracer = tracer.tagged("store")
private let managerTracer = storeTracer.tagged("manager")
private let trackableTracer = storeTracer.tagged("trackable")
private let selectedTracer = storeTracer.tagged("selected")

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

    func withTracking<T>(_ apply: () -> T, onUpdate: @escaping () -> Void) -> (value: T, id: Int) {
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
        return (result, id)
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
        var activeSubscriptions: [StoreSubscription] = []
        for id in subscriptionIds {
            if let subscription = idToSubscription.removeValue(forKey: id) {
                activeSubscriptions.append(subscription)
            }
        }

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

private let queue = DispatchQueue(label: "StoreManagerQueue", attributes: .concurrent)
private var _manager = StoreManager()
private var manager: StoreManager {
    get { queue.sync { _manager } }
    set { queue.async(flags: .barrier) { _manager = newValue } }
}

// MARK: - Store

class Store: CancellableHolder {
    var cancellables = Set<AnyCancellable>()

    private var trackableIdGen = IncrementalIdGenerator()
    private var trackableIdToSubscriptionIds: [Int: Set<Int>] = [:]

    fileprivate func generateTrackableId() -> Int { trackableIdGen.generate() }

    fileprivate func onAccess(of trackableId: Int) {
        let tracking = manager.tracking
        let _r = storeTracer.range("on access of \(trackableId), \(tracking.map { "with tracking \($0)" } ?? "without tracking")"); defer { _r() }
        if let tracking {
            var ids = trackableIdToSubscriptionIds[trackableId] ?? []
            ids.insert(tracking.subscriptionId)
            trackableIdToSubscriptionIds[trackableId] = ids
        }
    }

    fileprivate func onChange(of trackableId: Int) {
        let subscriptionIds = trackableIdToSubscriptionIds.removeValue(forKey: trackableId)
        let _r = storeTracer.range("on change of \(trackableId), \(subscriptionIds.map { "with \($0.count) subscriptions" } ?? "without subscription")"); defer { _r() }
        guard let subscriptionIds else { return }
        manager.notify(subscriptionIds: subscriptionIds)
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
        onAccess(of: id)
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
        for id in storage.trackableIds {
            onAccess(of: id)
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
        onChange(of: id)
        wrapper.value = newValue
        wrapper.didSetSubject.send(newValue)
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

// MARK: - Selected

@propertyWrapper
struct Selected<Value: Equatable>: DynamicProperty {
    fileprivate class Storage: ObservableObject {
        @Published var value: Value?
        var selector: () -> Value
        var name: String?
        var subscriptionId: Int?

        init(name: String? = nil, selector: @escaping () -> Value) {
            self.name = name
            self.selector = selector
            select()
        }

        func select() {
            let _r = selectedTracer.range(name.map { "select \($0)" } ?? "select"); defer { _r() }
            if let subscriptionId {
                manager.expire(subscriptionId: subscriptionId)
            }
            let (newValue, id) = manager.withTracking { selector() } onUpdate: { [weak self] in self?.select() }
            subscriptionId = id
            if value != newValue {
                selectedTracer.instant("updated")
                value = newValue
            }
        }
    }

    @StateObject fileprivate var storage: Storage

    var wrappedValue: Value { storage.value! }

    var projectedValue: Selected<Value> { self }

    // reselect
    func callAsFunction(_ selector: @escaping () -> Value) {
        storage.selector = selector
        storage.select()
    }

    init(_ selector: @escaping () -> Value, name: String? = nil) {
        _storage = StateObject(wrappedValue: Storage(name: name, selector: selector))
    }

    init(wrappedValue: @autoclosure @escaping () -> Value, name: String? = nil) {
        self.init(wrappedValue, name: name)
    }
}
