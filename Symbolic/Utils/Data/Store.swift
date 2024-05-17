import Foundation
import SwiftUI

private struct StoreSubscription {
    let callback: () -> Void
}

// MARK: - StoreManager

private class StoreManager {
    var subscriptionIdGen = IncrementalIdGenerator()
    var idToSubscription: [Int: StoreSubscription] = [:]

    struct TrackingContext {
        var subscriptionId: Int
    }

    var tracking: TrackingContext?

    struct UpdatingContext {
        var subscriptions: [StoreSubscription] = []
    }

    var updating: UpdatingContext?

    func withTracking<T>(_ apply: () -> T, onUpdate: @escaping () -> Void) -> T {
        guard tracking == nil else {
            print(tracer.rangeStack)
            fatalError("Nested tracking of store properties is not supported.")
        }
        let id = subscriptionIdGen.generate()
        let _r = tracer.range("[store] Tracking \(id)"); defer { _r() }
        tracking = TrackingContext(subscriptionId: id)
        defer { self.tracking = nil }

        let result = apply()

        idToSubscription[id] = .init(callback: onUpdate)
        return result
    }

    func withUpdating(_ apply: () -> Void) {
        let _r = tracer.range("[store] Updating"); defer { _r() }
        guard updating == nil else { apply(); return }

        self.updating = UpdatingContext()
        defer { self.updating = nil }

        apply()

        guard let updating else { return }
        for subscription in updating.subscriptions {
            subscription.callback()
        }
        tracer.instant("[store] subscriptions.count \(updating.subscriptions.count)")
    }

    func trigger(subscription id: Int) {
        let _r = tracer.range("[store] Trigger \(id)"); defer { _r() }
        guard let subscription = idToSubscription.removeValue(forKey: id) else { return }
        if updating != nil {
            updating?.subscriptions.append(subscription)
        } else {
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
        let _r = tracer.range("[store] On access of \(propertyId)"); defer { _r() }
        guard let subscriptionId = manager.tracking?.subscriptionId else { return }
        tracer.instant("[store] subscriptionId \(subscriptionId)")
        var ids = propertyIdToSubscriptionIds[propertyId] ?? []
        ids.insert(subscriptionId)
        propertyIdToSubscriptionIds[propertyId] = ids
    }

    fileprivate func onChange(of propertyId: Int) {
        let _r = tracer.range("[store] On change of \(propertyId)"); defer { _r() }
        guard let subscriptionIds = propertyIdToSubscriptionIds.removeValue(forKey: propertyId) else { return }
        tracer.instant("[store] subscriptionIds.count \(subscriptionIds.count)")
        for id in subscriptionIds {
            manager.trigger(subscription: id)
        }
    }
}

// MARK: - Trackable

@propertyWrapper
struct _Trackable<Instance: _StoreProtocol, Value> {
    fileprivate var id: Int?
    fileprivate var value: Value

    @available(*, unavailable, message: "@Trackable can only be applied to Store")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

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

extension Store: _StoreProtocol {}

struct StoreUpdater<S: _StoreProtocol> {
    let store: S

    func callAsFunction<T>(_ keypath: WritableKeyPath<S, _Trackable<S, T>>, _ value: T) {
        store.update(keypath, value)
//        print("[intent] StoreUpdater", keypath, value)
    }

    fileprivate init(store: S) {
        self.store = store
    }
}

extension _StoreProtocol {
    fileprivate func access<T>(keypath: ReferenceWritableKeyPath<Self, Trackable<T>>) -> T {
        let _r = tracer.range("[store] Access \(keypath)"); defer { _r() }
        let wrapper = self[keyPath: keypath]
        let id = wrapper.id ?? generatePropertyId()
        if wrapper.id == nil {
            self[keyPath: keypath].id = id
        }
        onAccess(of: id)
        return wrapper.value
    }

    fileprivate func update<T>(_ keypath: WritableKeyPath<Self, Trackable<T>>, _ newValue: T) {
        let _r = tracer.range("[store] Update \(keypath) with \(newValue)"); defer { _r() }
        var mutableSelf = self
        let wrapper = self[keyPath: keypath]
        let id = wrapper.id ?? generatePropertyId()
        if wrapper.id == nil {
            mutableSelf[keyPath: keypath].id = id
        }
        guard wrapper.needUpdate(newValue: newValue) else { return }
        onChange(of: id)
        mutableSelf[keyPath: keypath].value = newValue
    }

    func update(_ callback: (StoreUpdater<Self>) -> Void) {
        manager.withUpdating {
            callback(StoreUpdater(store: self))
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
