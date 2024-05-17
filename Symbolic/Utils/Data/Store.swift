import Foundation
import SwiftUI

private struct StoreSubscription {
    let callback: () -> Void
}

// MARK: - StoreManager

private class StoreManager {
    var subscriptionIdGen = IncrementalIdGenerator()

    var idToSubscription: [Int: StoreSubscription] = [:]

    var trackingSubscriptionId: Int?

    var pendingUpdateSubscriptions: [StoreSubscription] = []
    var pendingUpdateTask: Task<Void, Never>?

    func withTracking<T>(_ apply: () -> T, onUpdate: @escaping () -> Void) -> T {
        guard trackingSubscriptionId == nil else {
            fatalError("Nested tracking of store properties is not supported.")
        }
        let id = subscriptionIdGen.generate()
        trackingSubscriptionId = id
        defer { trackingSubscriptionId = nil }

        let result = apply()
        idToSubscription[id] = .init(callback: onUpdate)
        return result
    }

    func trigger(subscription id: Int) {
        guard let subscription = idToSubscription.removeValue(forKey: id) else { return }
        pendingUpdateSubscriptions.append(subscription)

        guard pendingUpdateTask == nil else { return }
        pendingUpdateTask = Task { @MainActor in
            for subscription in pendingUpdateSubscriptions {
                subscription.callback()
            }
            pendingUpdateSubscriptions = []
            pendingUpdateTask = nil
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
        guard let subscriptionId = manager.trackingSubscriptionId else { return }
        var ids = propertyIdToSubscriptionIds[propertyId] ?? []
        ids.insert(subscriptionId)
        propertyIdToSubscriptionIds[propertyId] = ids
    }

    fileprivate func onChange(of propertyId: Int) {
        guard let subscriptionIds = propertyIdToSubscriptionIds.removeValue(forKey: propertyId) else { return }
        for id in subscriptionIds {
            manager.trigger(subscription: id)
        }
    }
}

// MARK: - Trackable

@propertyWrapper
struct _Trackable<Instance: StoreProtocol, Value: Equatable> {
    var id: Int?
    var value: Value

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

protocol StoreProtocol: Store {
    typealias Trackable<T: Equatable> = _Trackable<Self, T>
}

extension Store: StoreProtocol {}

struct StoreUpdater<S: StoreProtocol> {
    let store: S

    func callAsFunction<T>(_ keypath: WritableKeyPath<S, _Trackable<S, T>>, _ value: T) {
        store.update(keypath, value)
    }

    fileprivate init(store: S) {
        self.store = store
    }
}

extension StoreProtocol {
    fileprivate func access<T>(keypath: ReferenceWritableKeyPath<Self, Trackable<T>>) -> T {
        let wrapper = self[keyPath: keypath]
        let id = wrapper.id ?? generatePropertyId()
        if wrapper.id == nil {
            self[keyPath: keypath].id = id
        }
        onAccess(of: id)
        return wrapper.value
    }

    fileprivate func update<T>(_ keypath: WritableKeyPath<Self, Trackable<T>>, _ newValue: T) {
        var mutableSelf = self
        let wrapper = self[keyPath: keypath]
        let id = wrapper.id ?? generatePropertyId()
        if wrapper.id == nil {
            mutableSelf[keyPath: keypath].id = id
        }
        guard wrapper.value != newValue else { return }
        onChange(of: id)
        mutableSelf[keyPath: keypath].value = newValue
    }

    func updater(_ callback: (StoreUpdater<Self>) -> Void) {
        callback(StoreUpdater(store: self))
    }
}

// MARK: - Selected

@propertyWrapper
struct StoreSelected<Value: Equatable>: DynamicProperty {
    private class Storage: ObservableObject {
        @Published var value: Value

        init(selector: @escaping () -> Value) {
            self.selector = selector
            value = selector()
            manager.withTracking { _ = selector() } onUpdate: { [weak self] in self?.select() }
        }

        private let selector: () -> Value

        private func select() {
            manager.withTracking { setIfChanged(&value, selector()) } onUpdate: { [weak self] in self?.select() }
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value { storage.value }

    var projectedValue: StoreSelected<Value> { self }

    init(_ selector: @escaping () -> Value) {
        _storage = StateObject(wrappedValue: Storage(selector: selector))
    }

    init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.init(wrappedValue)
    }
}
