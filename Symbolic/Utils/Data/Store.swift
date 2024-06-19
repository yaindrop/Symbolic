import Combine
import SwiftUI

private let subtracer = tracer.tagged("store", enabled: false)

private struct StoreSubscription {
    let id: Int
    let callback: () -> Void
}

// MARK: - StoreManager

private class StoreManager {
    private var subscriptionIdGen = IncrementalIdGenerator()
    private var idToSubscription: [Int: StoreSubscription] = [:]

    private var tracking: TrackingContext?
    private var updating: UpdatingContext?
    private var notifying: [NotifyingContext] = []
}

// MARK: tracking

extension StoreManager {
    class TrackingContext {
        let subscriptionId: Int

        init(subscriptionId: Int) {
            self.subscriptionId = subscriptionId
        }
    }

    var trackingId: Int? { tracking?.subscriptionId }

    func withTracking<T>(_ apply: () -> T, onNotify: @escaping () -> Void) -> (value: T, subscriptionId: Int) {
        guard tracking == nil else {
            fatalError("Nested tracking of store properties is not supported.")
        }
        let id = subscriptionIdGen.generate()
        let _r = subtracer.range("tracking, id=\(id)"); defer { _r() }

        let tracking = TrackingContext(subscriptionId: id)
        self.tracking = tracking
        let result = apply()
        self.tracking = nil

        idToSubscription[id] = .init(id: id, callback: onNotify)
        return (result, tracking.subscriptionId)
    }

    func expire(subscriptionId: Int) {
        idToSubscription.removeValue(forKey: subscriptionId)
    }
}

// MARK: updating

struct StoreUpdateConfigs {
    enum AnimationOverride {
        case override(Animation)
        case noAnimation
    }

    var syncNotify: Bool = false
    var animation: AnimationOverride?
}

extension StoreManager {
    class UpdatingContext: CancellableHolder {
        let configs: StoreUpdateConfigs
        var cancellables = Set<AnyCancellable>()
        var subscriptions: [StoreSubscription] = []
        var willNotifySubject = PassthroughSubject<Void, Never>()

        init(configs: StoreUpdateConfigs) {
            self.configs = configs
        }
    }

    var updatingWillNotify: AnyPublisher<Void, Never>? { updating?.willNotifySubject.eraseToAnyPublisher() }

    func withUpdating(configs: StoreUpdateConfigs = .init(), _ apply: () -> Void) {
        if updating != nil {
            let _r = subtracer.range("reenter updating"); defer { _r() }
            apply()
            return
        }
        let _r = subtracer.range("updating, configs=\(configs)"); defer { _r() }

        let updating = UpdatingContext(configs: configs)
        self.updating = updating
        apply()
        updating.willNotifySubject.send()
        self.updating = nil

        notifyAll(updating)
    }
}

// MARK: notifying

extension StoreManager {
    class NotifyingContext {
        let configs: StoreUpdateConfigs

        init(configs: StoreUpdateConfigs) {
            self.configs = configs
        }
    }

    var notifyingConfigs: StoreUpdateConfigs? { notifying.last?.configs }

    func notify(subscriptionIds: Set<Int>) {
        let _r = subtracer.range("notify"); defer { _r() }
        let activeSubscriptions = subscriptionIds.compactMap { idToSubscription.removeValue(forKey: $0) }
        updating.forSome {
            subtracer.instant("append \(activeSubscriptions.map { $0.id })")
            $0.subscriptions += activeSubscriptions
        } else: {
            for subscription in activeSubscriptions {
                let _r = subtracer.range("callback \(subscription.id)"); defer { _r() }
                subscription.callback()
            }
        }
    }

    private func notifyAll(_ context: UpdatingContext) {
        let _r = subtracer.range("notify all \(context.subscriptions.map { $0.id })"); defer { _r() }
        notifying.append(.init(configs: context.configs))
        for subscription in context.subscriptions {
            let _r = subtracer.range("callback \(subscription.id)"); defer { _r() }
            subscription.callback()
        }
        notifying.removeLast()
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
        let _r = subtracer.range("deriving"); defer { _r() }

        let deriving = DerivingContext()
        self.deriving = deriving
        let result = apply()
        self.deriving = nil
        subtracer.instant("trackableIds \(deriving.trackableIds)")

        return (result, deriving)
    }
}

private extension Store {
    func generateTrackableId() -> Int { trackableIdGen.generate() }

    func onTrack(of trackableId: Int, in subscriptionId: Int) {
        let _r = subtracer.range("on track of \(trackableId) in subscription \(subscriptionId)"); defer { _r() }
        var ids = trackableIdToSubscriptionIds[trackableId] ?? []
        ids.insert(subscriptionId)
        trackableIdToSubscriptionIds[trackableId] = ids
    }

    func onChange(of trackableId: Int) {
        let subscriptionIds = trackableIdToSubscriptionIds.removeValue(forKey: trackableId)
        let _r = subtracer.range("on change of \(trackableId), \(subscriptionIds.map { "with \($0.count) subscriptions" } ?? "without subscription")"); defer { _r() }
        guard let subscriptionIds else { return }
        manager.notify(subscriptionIds: subscriptionIds)
    }
}

// MARK: - StoreProtocol

protocol _StoreProtocol: Store {
    typealias Trackable<T: Equatable> = _Trackable<Self, T>
    typealias Derived<T: Equatable> = _Derived<Self, T>
}

extension Store: _StoreProtocol {}

private extension _StoreProtocol {
    // MARK: access trackable

    func access<T>(keyPath: ReferenceWritableKeyPath<Self, Trackable<T>>) -> T {
        let _r = subtracer.range("access trackable \(keyPath)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
        let id: Int
        if let wrapperId = wrapper.id {
            id = wrapperId
        } else {
            id = generateTrackableId()
            wrapper.id = id
        }
        if let trackingId = manager.trackingId {
            onTrack(of: id, in: trackingId)
        }
        if let deriving, !deriving.trackableIds.contains(id) {
            deriving.trackableIds.insert(id)
            deriving.publishers.append(wrapper.willNotifySubject.map { _ in () }.eraseToAnyPublisher())
        }
        return wrapper.value
    }

    // MARK: access derived

    func access<T>(keyPath: ReferenceWritableKeyPath<Self, Derived<T>>) -> T {
        let _r = subtracer.range("access trackable \(keyPath)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
        let value = wrapper.value ?? update(keyPath: keyPath)

        if let trackingId = manager.trackingId {
            for id in wrapper.trackableIds {
                onTrack(of: id, in: trackingId)
            }
        }
        if let deriving, !deriving.trackableIds.contains(wrapper.trackableIds) {
            deriving.trackableIds.formUnion(wrapper.trackableIds)
            deriving.publishers.append(wrapper.willNotifySubject.map { _ in () }.eraseToAnyPublisher())
        }
        return value
    }

    // MARK: update trackable

    func update<T>(keyPath: ReferenceWritableKeyPath<Self, Trackable<T>>, _ newValue: T, forced: Bool) {
        let _r = subtracer.range("update trackable \(keyPath) with \(newValue)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
        let id: Int
        if let wrapperId = wrapper.id {
            id = wrapperId
        } else {
            id = generateTrackableId()
            wrapper.id = id
        }
        guard forced || wrapper.value != newValue else { return }
        wrapper.value = newValue
        wrapper.didSetSubject.send(newValue)

        onChange(of: id)
        if wrapper.willNotifyCancellable == nil {
            wrapper.willNotifyCancellable = manager.updatingWillNotify?.sink {
                wrapper.willNotifySubject.send(wrapper.value)
                wrapper.willNotifyCancellable = nil
            }
        }
    }

    // MARK: update derived

    @discardableResult func update<T>(keyPath: ReferenceWritableKeyPath<Self, Derived<T>>) -> T {
        let _r = subtracer.range("update derived \(keyPath)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
        let (value, context) = withDeriving { wrapper.derive(self) }

        wrapper.value = value
        wrapper.willNotifySubject.send(value)

        wrapper.trackableIds = context.trackableIds
        wrapper.cancellables.removeAll()
        for publisher in context.publishers {
            publisher
                .sink { self.update(keyPath: keyPath) }
                .store(in: &wrapper.cancellables)
        }
        return value
    }
}

extension Store {
    struct Updater<S: _StoreProtocol> {
        let store: S

        func callAsFunction<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<S, S.Trackable<T>>, _ value: T, forced: Bool = false) {
            store.update(keyPath: keyPath, value, forced: forced)
        }

        fileprivate init(_ store: S) {
            self.store = store
        }
    }
}

extension _StoreProtocol {
    func update(_ callback: (Updater<Self>) -> Void) {
        manager.withUpdating {
            callback(Updater(self))
        }
    }
}

func withStoreUpdating(configs: StoreUpdateConfigs = .init(), _ apply: () -> Void) {
    manager.withUpdating(configs: configs, apply)
}

// MARK: - Trackable

@propertyWrapper
struct _Trackable<Instance: _StoreProtocol, Value: Equatable> {
    fileprivate var id: Int?
    fileprivate var value: Value

    fileprivate let didSetSubject = PassthroughSubject<Value, Never>()
    fileprivate let willNotifySubject = PassthroughSubject<Value, Never>()

    fileprivate var willNotifyCancellable: AnyCancellable?

    @available(*, unavailable, message: "@Trackable can only be applied to Store")
    var wrappedValue: Value { get { fatalError() } set { fatalError() } }

    struct Projected {
        let didSet: AnyPublisher<Value, Never>
        let willNotify: AnyPublisher<Value, Never>
    }

    var projectedValue: Projected { .init(didSet: didSetSubject.eraseToAnyPublisher(), willNotify: willNotifySubject.eraseToAnyPublisher()) }

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
    fileprivate let derive: (Instance) -> Value
    fileprivate var value: Value?

    fileprivate var trackableIds: Set<Int> = []
    fileprivate let willNotifySubject = PassthroughSubject<Value, Never>()

    fileprivate var cancellables = Set<AnyCancellable>()

    @available(*, unavailable, message: "@Derived can only be applied to Store")
    var wrappedValue: Value { get { fatalError() } set { fatalError() } }

    struct Projected {
        let willNotify: AnyPublisher<Value, Never>
    }

    var projectedValue: Projected { .init(willNotify: willNotifySubject.eraseToAnyPublisher()) }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: ReferenceWritableKeyPath<Instance, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Instance, Self>
    ) -> Value {
        get { instance.access(keyPath: storageKeyPath) }
        @available(*, unavailable) set {}
    }

    init(_ derive: @escaping (Instance) -> Value) {
        self.derive = derive
    }
}

// MARK: - Selector

class _Selector<Props>: ObservableObject, CancellableHolder {
    var name: String?
    var syncNotify: Bool { false }

    var props: Props?
    var cancellables = Set<AnyCancellable>()

    fileprivate let retrackSubject = PassthroughSubject<Void, Never>()

    required init() {}
}

private extension _Selector {
    func setup(_ name: @autoclosure () -> String, _ props: Props) {
        let name = name()
        let _r = subtracer.range("setup selector \(name)"); defer { _r() }
        self.name = name
        if self.props == nil {
            self.props = props
        }
    }

    func update(_ props: Props) {
        self.props = props
        retrackSubject.send()
    }
}

// MARK: - SelectorProtocol

protocol _SelectorProtocol: AnyObject {
    associatedtype Props
    var name: String? { get }
    var syncNotify: Bool { get }
    var props: Props? { get }

    func notify()
    func setupRetrack(callback: @escaping () -> Void)

    typealias Selected<T: Equatable> = _Selected<Self, T>
    typealias Formula<T> = _Formula<Self, T>
}

extension _Selector: _SelectorProtocol {
    func notify() {
        objectWillChange.send()
    }

    func setupRetrack(callback: @escaping () -> Void) {
        retrackSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }
}

private extension _SelectorProtocol {
    // MARK: access selected

    func access<T>(keyPath: ReferenceWritableKeyPath<Self, Selected<T>>) -> T {
        let _r = subtracer.range("access selector \(name!) \(keyPath)"); defer { _r() }
        return self[keyPath: keyPath].value ?? track(keyPath: keyPath)
    }

    // MARK: track selected

    @discardableResult
    func track<T>(keyPath: ReferenceWritableKeyPath<Self, Selected<T>>, configs: StoreUpdateConfigs = .init()) -> T {
        let _r = subtracer.range("track selector \(name!) \(keyPath)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
        let (newValue, subscriptionId) = manager.withTracking { wrapper.selector(self.props!) } onNotify: { [weak self] in self?.notify(keyPath: keyPath) }
        wrapper.subscriptionId = subscriptionId

        if wrapper.value == nil {
            wrapper.value = newValue
            setupRetrack { [weak self] in self?.retrack(keyPath: keyPath) }
            subtracer.instant("setup \(newValue)")
        } else if wrapper.value != newValue {
            let animation = wrapper.animation(with: configs)
            wrapper.value = newValue
            if let animation {
                withAnimation(animation) { notify() }
            } else {
                notify()
            }
            subtracer.instant("updated \(newValue), animation=\(animation?.description ?? "nil")")
        } else {
            subtracer.instant("unchanged")
        }
        return newValue
    }

    // MARK: retrack selected

    func retrack<T>(keyPath: ReferenceWritableKeyPath<Self, Selected<T>>) {
        let _r = subtracer.range("retrack selector \(name!) \(keyPath)"); defer { _r() }
        @Ref(self, keyPath) var wrapper
        if let subscriptionId = wrapper.subscriptionId {
            manager.expire(subscriptionId: subscriptionId)
        }
        track(keyPath: keyPath)
    }

    // MARK: notify selected

    func notify<T>(keyPath: ReferenceWritableKeyPath<Self, Selected<T>>) {
        @Ref(self, keyPath) var wrapper
        let configs = manager.notifyingConfigs ?? .init()
        let syncNotify = syncNotify || wrapper.syncNotify || configs.syncNotify
        let _r = subtracer.range("update selector \(name!) \(keyPath), syncNotify=\(syncNotify), configs=\(configs)"); defer { _r() }
        wrapper.asyncNotifyTask?.cancel()
        if syncNotify {
            track(keyPath: keyPath, configs: configs)
        } else {
            wrapper.asyncNotifyTask = Task(priority: .high) { @MainActor [weak self] in
                guard let self else { return }
                self[keyPath: keyPath].asyncNotifyTask = nil
                self.track(keyPath: keyPath, configs: configs)
            }
        }
    }
}

// MARK: - Selected

@propertyWrapper
struct _Selected<Instance: _SelectorProtocol, Value: Equatable> {
    var syncNotify: Bool
    var animation: Animation?
    let selector: (Instance.Props) -> Value

    var value: Value?
    var subscriptionId: Int?
    var asyncNotifyTask: Task<Void, Never>?

    @available(*, unavailable, message: "@Selected can only be applied to Selector")
    var wrappedValue: Value { get { fatalError() } set { fatalError() } }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: ReferenceWritableKeyPath<Instance, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Instance, Self>
    ) -> Value {
        get { instance.access(keyPath: storageKeyPath) }
        @available(*, unavailable) set {}
    }

    init(syncNotify: Bool = false, animation: Animation? = nil, _ selector: @escaping (Instance.Props) -> Value) {
        self.syncNotify = syncNotify
        self.animation = animation
        self.selector = selector
    }

    init(syncNotify: Bool = false, animation: Animation? = nil, _ selector: @escaping () -> Value) {
        self.syncNotify = syncNotify
        self.animation = animation
        self.selector = { _ in selector() }
    }
}

private extension _Selected {
    func animation(with configs: StoreUpdateConfigs) -> Animation? {
        if let override = configs.animation {
            if case let .override(animation) = override {
                animation
            } else {
                nil
            }
        } else {
            animation
        }
    }
}

@propertyWrapper
struct _Formula<Instance: _SelectorProtocol, Value> {
    let wrappedValue: (Instance.Props) -> Value

    init(_ formula: @escaping (Instance.Props) -> Value) {
        wrappedValue = formula
    }
}

// MARK: - SelectorHolder

@propertyWrapper
struct _SelectorWrapper<Props, Selector: _Selector<Props>>: DynamicProperty {
    @StateObject fileprivate var selector = Selector()
    var wrappedValue: Selector { selector }
}

protocol SelectorHolder {
    associatedtype Selector: SelectorBase
    typealias SelectorBase = _Selector<Monostate>
    typealias SelectorWrapper = _SelectorWrapper<Monostate, Selector>

    var selector: Selector { get }
}

extension SelectorHolder {
    func setupSelector<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        selector.setup(String(describing: type(of: self)), .value)
        return content()
    }
}

protocol ComputedSelectorHolder {
    associatedtype SelectorProps: Equatable
    associatedtype Selector: SelectorBase
    typealias SelectorBase = _Selector<SelectorProps>
    typealias SelectorWrapper = _SelectorWrapper<SelectorProps, Selector>

    var selector: Selector { get }
}

extension ComputedSelectorHolder {
    func setupSelector<Content: View>(_ props: SelectorProps, @ViewBuilder content: @escaping () -> Content) -> some View {
        selector.setup(String(describing: type(of: self)), props)
        return content().onChange(of: props) { selector.update(props) }
    }
}
