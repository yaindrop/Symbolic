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

    func withTracking<T>(_ apply: () -> T, onUpdate: @escaping () -> Void) -> T {
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
        return result
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
        let _r = managerTracer.range("notify \(subscriptionIds)"); defer { _r() }
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
            subscription.callback()
        }
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

    private var propertyIdGen = IncrementalIdGenerator()
    private var propertyIdToSubscriptionIds: [Int: Set<Int>] = [:]

    fileprivate func generatePropertyId() -> Int { propertyIdGen.generate() }

    fileprivate func onAccess(of propertyId: Int) {
        let subscriptionId = manager.tracking?.subscriptionId
        let _r = storeTracer.range("on access of \(propertyId), \(subscriptionId.map { "with tracking \($0)" } ?? "without tracking")"); defer { _r() }
        guard let subscriptionId else { return }
        var ids = propertyIdToSubscriptionIds[propertyId] ?? []
        ids.insert(subscriptionId)
        propertyIdToSubscriptionIds[propertyId] = ids
    }

    fileprivate func onChange(of propertyId: Int) {
        let subscriptionIds = propertyIdToSubscriptionIds.removeValue(forKey: propertyId)
        let _r = storeTracer.range("on change of \(propertyId), \(subscriptionIds.map { "with subscriptions \($0)" } ?? "without subscription")"); defer { _r() }
        guard let subscriptionIds else { return }
        manager.notify(subscriptionIds: subscriptionIds)
    }
}

// MARK: - Trackable

@propertyWrapper
struct _Trackable<Instance: _StoreProtocol, Value> {
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
        let didSet: PassthroughSubject<Value, Never>
        let willUpdate: PassthroughSubject<Value, Never>
    }

    var projectedValue: Projected { .init(didSet: didSetSubject, willUpdate: willUpdateSubject) }

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

private extension _Trackable {
    func needUpdate(newValue _: Value) -> Bool { true }
}

private extension _Trackable where Value: Equatable {
    func needUpdate(newValue: Value) -> Bool { value != newValue }
}

// MARK: - StoreProtocol

protocol _StoreProtocol: Store {
    typealias Trackable<T> = _Trackable<Self, T>
}

extension Store: _StoreProtocol {
    struct Updater<S: _StoreProtocol> {
        let store: S

        func callAsFunction<T>(_ keypath: ReferenceWritableKeyPath<S, S.Trackable<T>>, _ value: T) {
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
            id = generatePropertyId()
            wrapper.id = id
        }
        onAccess(of: id)
        return wrapper.value
    }

    fileprivate func update<T>(_ keypath: ReferenceWritableKeyPath<Self, Trackable<T>>, _ newValue: T) {
        let _r = trackableTracer.range("update \(keypath) with \(newValue)"); defer { _r() }
        @Ref(self, keypath) var wrapper
        let id: Int
        if let wrapperId = wrapper.id {
            id = wrapperId
        } else {
            id = generatePropertyId()
            wrapper.id = id
        }
        guard wrapper.needUpdate(newValue: newValue) else { return }
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
struct Selected<Value>: DynamicProperty {
    fileprivate class Storage: ObservableObject {
        var name: String?
        @Published var value: Value?

        init(name: String? = nil, selector: @escaping () -> Value) {
            self.name = name
            self.selector = selector
            select()
        }

        private let selector: () -> Value

        private func select() {
            let _r = selectedTracer.range("select \(name ?? "")"); defer { _r() }
            let newValue = manager.withTracking { selector() } onUpdate: { [weak self] in self?.select() }
            if needUpdate(newValue: newValue) {
                selectedTracer.instant("updated")
                value = newValue
            }
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value { storage.value! }

    var projectedValue: Selected<Value> { self }

    init(_ selector: @escaping () -> Value, name: String? = nil) {
        _storage = StateObject(wrappedValue: Storage(name: name, selector: selector))
    }

    init(wrappedValue: @autoclosure @escaping () -> Value, name: String? = nil) {
        self.init(wrappedValue, name: name)
    }
}

private extension Selected.Storage {
    func needUpdate(newValue _: Value) -> Bool { true }
}

private extension Selected.Storage where Value: Equatable {
    func needUpdate(newValue: Value) -> Bool { value != newValue }
}
