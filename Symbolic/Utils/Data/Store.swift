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

    private(set) var tracking: TrackingContext?
    private var updating: UpdatingContext?
}

// MARK: tracking

extension StoreManager {
    class TrackingContext {
        let subscriptionId: Int

        init(subscriptionId: Int) {
            self.subscriptionId = subscriptionId
        }
    }

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
}

// MARK: updating

extension StoreManager {
    class UpdatingContext: CancellableHolder {
        var cancellables = Set<AnyCancellable>()
        var subscriptions: [StoreSubscription] = []
        var willUpdateSubject = PassthroughSubject<Void, Never>()
    }

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

    var willUpdate: AnyPublisher<Void, Never>? {
        updating.map { $0.willUpdateSubject.eraseToAnyPublisher() }
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

    fileprivate private(set) var deriving: DerivingContext?
}

// MARK: deriving

private extension Store {
    class DerivingContext {
        var trackableIds: Set<Int> = []
        var publishers: [AnyPublisher<Void, Never>] = []
    }

    func withDeriving<T>(_ apply: () -> T) -> (value: T, DerivingContext) {
        guard deriving == nil else {
            fatalError("Nested deriving of store properties is not supported.")
        }
        let _r = storeTracer.range("deriving"); defer { _r() }

        let deriving = DerivingContext()
        self.deriving = deriving
        let result = apply()
        self.deriving = nil
        storeTracer.instant("trackableIds \(deriving.trackableIds)")

        return (result, deriving)
    }
}

private extension Store {
    func generateTrackableId() -> Int { trackableIdGen.generate() }

    func onTrack(of trackableId: Int, in subscriptionId: Int) {
        let _r = storeTracer.range("on track of \(trackableId) in subscription \(subscriptionId)"); defer { _r() }
        var ids = trackableIdToSubscriptionIds[trackableId] ?? []
        ids.insert(subscriptionId)
        trackableIdToSubscriptionIds[trackableId] = ids
    }

    func onChange(of trackableId: Int) -> Set<Int> {
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
    fileprivate var willUpdateCancellable: AnyCancellable?

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
        get { instance.access(keyPath: storageKeyPath) }
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
        var derive: (Instance) -> Value
        var value: Value?

        var trackableIds: Set<Int> = []
        let willUpdateSubject = PassthroughSubject<Value, Never>()

        var cancellables = Set<AnyCancellable>()

        init(derive: @escaping (Instance) -> Value) {
            self.derive = derive
        }

        func update(_ instance: Instance) {
            let _r = trackableTracer.range("update derived"); defer { _r() }
            let (value, context) = instance.withDeriving { derive(instance) }

            self.value = value
            willUpdateSubject.send(value)

            trackableIds = context.trackableIds
            cancellables.removeAll()
            for publisher in context.publishers {
                publisher
                    .sink { self.update(instance) }
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
        get { instance.access(keyPath: storageKeyPath) }
        @available(*, unavailable) set {}
    }

    init(_ derive: @escaping (Instance) -> Value) {
        storage = .init(derive: derive)
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

        func callAsFunction<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<S, S.Trackable<T>>, _ value: T) {
            store.update(keyPath, value)
        }

        fileprivate init(_ store: S) {
            self.store = store
        }
    }
}

extension _StoreProtocol {
    fileprivate func access<T>(keyPath: ReferenceWritableKeyPath<Self, Trackable<T>>) -> T {
        let _r = trackableTracer.range("access \(keyPath)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
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
        if let deriving = deriving, !deriving.trackableIds.contains(id) {
            deriving.trackableIds.insert(id)
            deriving.publishers.append(wrapper.willUpdateSubject.map { _ in () }.eraseToAnyPublisher())
        }
        return wrapper.value
    }

    fileprivate func access<T>(keyPath: ReferenceWritableKeyPath<Self, Derived<T>>) -> T {
        let _r = trackableTracer.range("access \(keyPath)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
        let storage = wrapper.storage
        if storage.value == nil {
            storage.update(self)
        }
        if let tracking = manager.tracking {
            for id in storage.trackableIds {
                onTrack(of: id, in: tracking.subscriptionId)
            }
        }
        if let deriving = deriving, !deriving.trackableIds.contains(storage.trackableIds) {
            deriving.trackableIds.formUnion(storage.trackableIds)
            deriving.publishers.append(storage.willUpdateSubject.map { _ in () }.eraseToAnyPublisher())
        }
        return storage.value!
    }

    fileprivate func update<T>(_ keyPath: ReferenceWritableKeyPath<Self, Trackable<T>>, _ newValue: T) {
        let _r = trackableTracer.range("update \(keyPath) with \(newValue)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
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
        if wrapper.willUpdateCancellable == nil {
            wrapper.willUpdateCancellable = manager.willUpdate?.sink {
                wrapper.willUpdateSubject.send(wrapper.value)
                wrapper.willUpdateCancellable = nil
            }
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

// MARK: - Selector

protocol _SelectorProtocol: AnyObject {
    associatedtype Props: Equatable
    var props: Props? { get }
    func onUpdate()
    func onRetrack(callback: @escaping () -> Void)

    typealias Tracked<T: Equatable> = _Tracked<Self, T>
}

class _Selector<Props: Equatable>: _SelectorProtocol, ObservableObject, CancellableHolder {
    struct Configs {
        var name: String?
        var syncUpdate: Bool

        init(name: String? = nil, syncUpdate: Bool = false) {
            self.name = name
            self.syncUpdate = syncUpdate
        }
    }

    var configs: Configs { .init() }

    var props: Props?
    var cancellables = Set<AnyCancellable>()

    private var updateTask: Task<Void, Never>?
    fileprivate let retrackSubject = PassthroughSubject<Void, Never>()

    func setup(_ props: Props) {
        if self.props == nil {
            self.props = props
        }
    }

    func onUpdate() {
        if configs.syncUpdate {
            objectWillChange.send()
            return
        }
        guard updateTask == nil else { return }
        updateTask = Task(priority: .high) { @MainActor in
            self.objectWillChange.send()
            self.updateTask = nil
        }
    }

    func onRetrack(callback: @escaping () -> Void) {
        retrackSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    deinit {
        updateTask?.cancel()
    }
}

// MARK: - Tracked

@propertyWrapper
struct _Tracked<Instance: _SelectorProtocol, Value: Equatable> {
    let name: String?
    let selector: (Instance.Props) -> Value
    var value: Value?
    var subscriptionId: Int?

    @available(*, unavailable, message: "@Tracked can only be applied to SelectedModel")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: ReferenceWritableKeyPath<Instance, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Instance, Self>
    ) -> Value {
        get { instance.access(keyPath: storageKeyPath) }
        @available(*, unavailable) set {}
    }

    init(_ selector: @escaping (Instance.Props) -> Value) {
        name = nil
        self.selector = selector
    }

    init(_ selector: @escaping () -> Value) {
        name = nil
        self.selector = { _ in selector() }
    }

    init(_ name: String? = nil, _ selector: @escaping (Instance.Props) -> Value) {
        self.name = name
        self.selector = selector
    }

    init(_ name: String? = nil, _ selector: @escaping () -> Value) {
        self.name = name
        self.selector = { _ in selector() }
    }
}

// MARK: - SelectorProtocol

private extension _SelectorProtocol {
    func access<T>(keyPath: ReferenceWritableKeyPath<Self, Tracked<T>>) -> T {
        let _r = trackableTracer.range("access \(keyPath)"); defer { _r() }
        return self[keyPath: keyPath].value ?? track(keyPath: keyPath)
    }

    @discardableResult
    func track<T>(keyPath: ReferenceWritableKeyPath<Self, Tracked<T>>) -> T {
        @Ref(self, keyPath) var wrapper
        let _r = selectedTracer.range(wrapper.name.map { "track \($0)" } ?? "track"); defer { _r() }
        if let subscriptionId = wrapper.subscriptionId {
            manager.expire(subscriptionId: subscriptionId)
        }

        let (newValue, context) = manager.withTracking { wrapper.selector(self.props!) } onUpdate: { [weak self] in self?.track(keyPath: keyPath) }
        wrapper.subscriptionId = context.subscriptionId

        if wrapper.value == nil {
            wrapper.value = newValue
            onRetrack { self.track(keyPath: keyPath) }
            selectedTracer.instant("setup")
        } else if wrapper.value != newValue {
            wrapper.value = newValue
            onUpdate()
            selectedTracer.instant("updated \(newValue)")
        } else {
            selectedTracer.instant("unchanged")
        }
        return newValue
    }
}

protocol SelectorHolder {
    associatedtype Selector: _Selector<Monostate>
    typealias SelectorBase = _Selector<Monostate>
    var selector: Selector { get }
}

extension SelectorHolder {
    func setupSelector<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        selector.setup(.value)
        return content()
    }
}

protocol ComputedSelectorHolder {
    associatedtype SelectorProps: Equatable
    associatedtype Selector: _Selector<SelectorProps>
    typealias SelectorBase = _Selector<SelectorProps>
    var selector: Selector { get }
}

extension ComputedSelectorHolder {
    func setupSelector<Content: View>(_ props: SelectorProps, @ViewBuilder content: @escaping () -> Content) -> some View {
        selector.setup(props)
        return content()
            .onChange(of: props) {
                selector.props = props
                selector.retrackSubject.send()
            }
    }
}
