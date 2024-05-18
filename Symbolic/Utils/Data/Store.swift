import Combine
import Foundation
import SwiftUI

fileprivate let storeTracer = tracer.tagged("store")
fileprivate let managerTracer = storeTracer.tagged("manager")
fileprivate let trackableTracer = storeTracer.tagged("trackable")

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
        let _r = managerTracer.range("Tracking \(id)"); defer { _r() }

        tracking = TrackingContext(subscriptionId: id)
        defer { self.tracking = nil }

        let result = apply()

        idToSubscription[id] = .init(id: id, callback: onUpdate)
        return result
    }

    // MARK: updating

    struct UpdatingContext {
        var subscriptions: [StoreSubscription] = []
    }

    private var updating: UpdatingContext?

    func withUpdating(_ apply: () -> Void) {
        if updating != nil {
            let _r = managerTracer.range("Reenter updating"); defer { _r() }
            apply()
            return
        }
        let _r = managerTracer.range("Updating"); defer { _r() }

        updating = UpdatingContext()
        defer { self.updating = nil }

        apply()

        notifyAllUpdating()
    }

    func notify(subscription id: Int) {
        guard let subscription = idToSubscription.removeValue(forKey: id) else {
            managerTracer.instant("Notifying expired \(id)")
            return
        }

        updating.forSome {
            managerTracer.instant("Append notifying of \(id)")
            $0.subscriptions.append(subscription)
        } else: {
            let _r = managerTracer.range("Notifying \(id)"); defer { _r() }
            subscription.callback()
        }
    }

    private func notifyAllUpdating() {
        guard let updating else { return }
        let _r = managerTracer.range("Notifying all \(updating.subscriptions.map { $0.id })"); defer { _r() }
        for subscription in updating.subscriptions {
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

class Store {
    private var propertyIdGen = IncrementalIdGenerator()
    private var propertyIdToSubscriptionIds: [Int: Set<Int>] = [:]

    fileprivate func generatePropertyId() -> Int { propertyIdGen.generate() }

    fileprivate func onAccess(of propertyId: Int) {
        let subscriptionId = manager.tracking?.subscriptionId
        let _r = storeTracer.range("On access of \(propertyId), \(subscriptionId.map { "with tracking \($0)" } else: { "without tracking" })"); defer { _r() }
        guard let subscriptionId else { return }
        var ids = propertyIdToSubscriptionIds[propertyId] ?? []
        ids.insert(subscriptionId)
        propertyIdToSubscriptionIds[propertyId] = ids
    }

    fileprivate func onChange(of propertyId: Int) {
        let subscriptionIds = propertyIdToSubscriptionIds.removeValue(forKey: propertyId)
        let _r = storeTracer.range("On change of \(propertyId), \(subscriptionIds.map { "with subscriptions \($0)" } else: { "without subscription" })"); defer { _r() }
        guard let subscriptionIds else { return }
        for id in subscriptionIds {
            manager.notify(subscription: id)
        }
    }
}

// MARK: - Trackable

@propertyWrapper
struct _Trackable<Instance: _StoreProtocol, Value> {
    fileprivate var id: Int?
    fileprivate var value: Value
    fileprivate let didSetSubject = PassthroughSubject<Value, Never>()

    @available(*, unavailable, message: "@Trackable can only be applied to Store")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    var projectedValue: PassthroughSubject<Value, Never> { didSetSubject }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: ReferenceWritableKeyPath<Instance, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Instance, Self>
    ) -> Value {
        get { instance.access(keypath: storageKeyPath) }
        @available(*, unavailable) set { }
    }

    init(wrappedValue: Value) {
        value = wrappedValue
    }
}

extension _Trackable {
    fileprivate func needUpdate(newValue: Value) -> Bool { true }
}

extension _Trackable where Value: Equatable {
    fileprivate func needUpdate(newValue: Value) -> Bool { value != newValue }
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
        let _r = trackableTracer.range("Access \(keypath)"); defer { _r() }
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
        let _r = trackableTracer.range("Update \(keypath) with \(newValue)"); defer { _r() }
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
        @Published var value: Value?

        init(selector: @escaping () -> Value) {
            self.selector = selector
            select()
        }

        private let selector: () -> Value

        private func select() {
            let newValue = manager.withTracking { selector() } onUpdate: { [weak self] in self?.select() }
            if needUpdate(newValue: newValue) {
                value = newValue
            }
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value { storage.value! }

    var projectedValue: Selected<Value> { self }

    init(_ selector: @escaping () -> Value) {
        _storage = StateObject(wrappedValue: Storage(selector: selector))
    }

    init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.init(wrappedValue)
    }
}

extension Selected.Storage {
    fileprivate func needUpdate(newValue: Value) -> Bool { true }
}

extension Selected.Storage where Value: Equatable {
    fileprivate func needUpdate(newValue: Value) -> Bool { value != newValue }
}
