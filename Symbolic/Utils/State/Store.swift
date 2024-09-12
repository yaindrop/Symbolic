import Combine
import SwiftUI

// MARK: - tracer

private let subtracer = tracer.tagged("store", enabled: true)

private extension Tracer {
    // MARK: manager

    struct Tracking: ReflectedStringMessage {
        let subscriptionId: Int
    }

    struct Updating: ReflectedStringMessage {
        let configs: PartialSelectorConfigs
    }

    struct UpdatingReenter: ReflectedStringMessage {}

    struct NotifyingAppend: ReflectedStringMessage {
        let subscriptionIds: [Int]
    }

    struct NotifyingCallback: ReflectedStringMessage {
        let subscriptionId: Int
    }

    struct NotifyingAll: ReflectedStringMessage {
        let subscriptionIds: [Int]
    }

    struct Deriving<S, K>: ReflectedStringMessage {
        let keyPath: KeyPath<S, K>
    }

    struct DerivingResult: ReflectedStringMessage {
        let trackableIds: Set<Int>
    }

    // MARK: store

    struct StoreAccess<S, K>: ReflectedStringMessage {
        let keyPath: KeyPath<S, K>
    }

    struct StoreUpdate<S, K>: ReflectedStringMessage {
        let trackableId: Int, keyPath: KeyPath<S, K>
    }

    struct StoreUpdateNotify<S, K, T>: ReflectedStringMessage {
        let keyPath: KeyPath<S, K>, newValue: T
    }

    // MARK: selector

    struct SelectorSetup: ReflectedStringMessage {
        let name: String
    }

    struct SelectorAccess<S, K>: ReflectedStringMessage {
        let name: String, keyPath: KeyPath<S, K>
    }

    struct SelectorTrack<S, K>: ReflectedStringMessage {
        let name: String, keyPath: KeyPath<S, K>, configs: SelectorConfigs
    }

    struct SelectorTrackSetup<T>: ReflectedStringMessage {
        let newValue: T
    }

    struct SelectorTrackUpdate<T>: ReflectedStringMessage {
        let newValue: T
    }

    struct SelectorTrackUnchanged: ReflectedStringMessage {}

    struct SelectorRetrack<S, K>: ReflectedStringMessage {
        let name: String, keyPath: KeyPath<S, K>
    }

    struct SelectorNotify: ReflectedStringMessage {
        let notifyingId: Int?
    }
}

// MARK: - SelectorConfigs

struct SelectorConfigs {
    var alwaysNotify: Bool = false
    var syncNotify: Bool = false
    var animation: AnimationPreset? = nil
}

extension SelectorConfigs: TriviallyCloneable {
    static var alwaysNotify: Self { .init(alwaysNotify: true) }
    static var syncNotify: Self { .init(syncNotify: true) }
    static func animation(_ animation: AnimationPreset?) -> Self { .init(animation: animation) }
}

struct PartialSelectorConfigs {
    var alwaysNotify: Bool? = nil
    var syncNotify: Bool? = nil
    var animation: AnimationPreset?? = nil
}

extension PartialSelectorConfigs: TriviallyCloneable {
    static var alwaysNotify: Self { .init(alwaysNotify: true) }
    static var syncNotify: Self { .init(syncNotify: true) }
    static func animation(_ animation: AnimationPreset?) -> Self { .init(animation: animation) }
}

// MARK: - StoreSubscription

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
    private var notifyingStack: [NotifyingContext] = []
    private var notifying: NotifyingContext? { notifyingStack.last }
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

    func expire(subscriptionId: Int) {
        idToSubscription.removeValue(forKey: subscriptionId)
    }

    func withTracking<T>(_ apply: () -> T, onNotify: @escaping () -> Void) -> (value: T, subscriptionId: Int) {
        guard tracking == nil else {
            fatalError("Nested tracking of store properties is not supported.")
        }
        let id = subscriptionIdGen.generate()
        let _r = subtracer.range(Tracer.Tracking(subscriptionId: id)); defer { _r() }

        let tracking = TrackingContext(subscriptionId: id)
        let result = withAssigned(self, \.tracking, tracking, apply)

        idToSubscription[id] = .init(id: id, callback: onNotify)
        return (result, tracking.subscriptionId)
    }
}

// MARK: updating

extension StoreManager {
    class UpdatingContext {
        let configs: PartialSelectorConfigs
        var subscriptions: [StoreSubscription] = []
        @Passthrough<Void> var willNotify

        var subscriptionIds: Set<Int> { .init(subscriptions.map { $0.id }) }

        init(configs: PartialSelectorConfigs) {
            self.configs = configs
        }
    }

    var updatingWillNotify: AnyPublisher<Void, Never>? { updating?.$willNotify }

    func withUpdating(configs: PartialSelectorConfigs = .init(), _ apply: () -> Void) {
        if updating != nil {
            let _r = subtracer.range(Tracer.UpdatingReenter()); defer { _r() }
            apply()
            return
        }
        let _r = subtracer.range(Tracer.Updating(configs: configs)); defer { _r() }

        let updating = UpdatingContext(configs: configs)
        withAssigned(self, \.updating, updating) {
            apply()
            var subscriptionIds: Set<Int> = []
            repeat {
                subscriptionIds = updating.subscriptionIds
                updating.willNotify.send()
            } while updating.subscriptionIds != subscriptionIds
        }

        withNotifying(updating)
    }
}

// MARK: notifying

extension StoreManager {
    class NotifyingContext {
        let configs: PartialSelectorConfigs
        var subscriptionId: Int?

        init(configs: PartialSelectorConfigs) {
            self.configs = configs
        }
    }

    var notifyingConfigs: PartialSelectorConfigs? { notifying?.configs }

    var notifyingId: Int? { notifying?.subscriptionId }

    func notify(subscriptionIds: Set<Int>) {
        let activeSubscriptions = subscriptionIds.compactMap { idToSubscription.removeValue(forKey: $0) }
        updating.forSome {
            subtracer.instant(Tracer.NotifyingAppend(subscriptionIds: activeSubscriptions.map { $0.id }))
            $0.subscriptions += activeSubscriptions
        } else: {
            for subscription in activeSubscriptions {
                let _r = subtracer.range(Tracer.NotifyingCallback(subscriptionId: subscription.id)); defer { _r() }
                subscription.callback()
            }
        }
    }

    private func withNotifying(_ context: UpdatingContext) {
        let _r = subtracer.range(Tracer.NotifyingAll(subscriptionIds: context.subscriptions.map { $0.id })); defer { _r() }
        withLast(self, \.notifyingStack, .init(configs: context.configs)) {
            for subscription in context.subscriptions {
                let _r = subtracer.range(Tracer.NotifyingCallback(subscriptionId: subscription.id)); defer { _r() }
                notifying?.subscriptionId = subscription.id
                subscription.callback()
            }
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

class Store: CancellablesHolder {
    var cancellables = Set<AnyCancellable>()

    fileprivate var trackableIdGen = IncrementalIdGenerator()
    fileprivate var trackableIdToSubscriptionIds: [Int: Set<Int>] = [:]

    fileprivate private(set) var derivingStack: [DerivingContext] = []
    fileprivate var deriving: DerivingContext? { derivingStack.last }
}

// MARK: deriving

private extension Store {
    class DerivingContext {
        var trackableIds: Set<Int> = []
        var publishers: [AnyPublisher<Void, Never>] = []
    }

    func withDeriving<T>(_ apply: () -> T) -> (newValue: T, DerivingContext) {
        let deriving = DerivingContext()
        let result = withLast(self, \.derivingStack, deriving, apply)
        subtracer.instant(Tracer.DerivingResult(trackableIds: deriving.trackableIds))

        return (result, deriving)
    }
}

// MARK: - StoreProtocol

protocol _StoreProtocol: Store {
    typealias Trackable<T: Equatable> = _Trackable<Self, T>
    typealias Derived<T: Equatable> = _Derived<Self, T>
}

extension Store: _StoreProtocol {}

private extension _StoreProtocol {
    var name: String { .init(describing: type(of: self)) }

    // MARK: access trackable

    func access<T>(keyPath: ReferenceWritableKeyPath<Self, Trackable<T>>) -> T {
        @Ref(self, keyPath) var wrapper
        let id: Int
        if let wrapperId = wrapper.id {
            id = wrapperId
        } else {
            id = trackableIdGen.generate()
            wrapper.id = id
        }
        if let trackingId = manager.trackingId {
            var ids = trackableIdToSubscriptionIds[id] ?? []
            if !ids.contains(trackingId) {
                let _r = subtracer.range(Tracer.StoreAccess(keyPath: keyPath)); defer { _r() }
                ids.insert(trackingId)
                trackableIdToSubscriptionIds[id] = ids
            }
        }
        if let deriving, !deriving.trackableIds.contains(id) {
            let _r = subtracer.range(Tracer.StoreAccess(keyPath: keyPath)); defer { _r() }
            deriving.trackableIds.insert(id)
            deriving.publishers.append(wrapper.$willNotify.eraseToVoidPublisher())
        }
        return wrapper.value
    }

    // MARK: access derived

    func access<T>(keyPath: ReferenceWritableKeyPath<Self, Derived<T>>) -> T {
        let _r = subtracer.range(Tracer.StoreAccess(keyPath: keyPath)); defer { _r() }
        @Ref(self, keyPath) var wrapper
        let value = wrapper.value ?? update(keyPath: keyPath)

        if let trackingId = manager.trackingId {
            for id in wrapper.trackableIds {
                var ids = trackableIdToSubscriptionIds[id] ?? []
                if !ids.contains(trackingId) {
                    ids.insert(trackingId)
                    trackableIdToSubscriptionIds[id] = ids
                }
            }
        }
        if let deriving, !deriving.trackableIds.contains(wrapper.trackableIds) {
            deriving.trackableIds.formUnion(wrapper.trackableIds)
            deriving.publishers.append(wrapper.$willNotify.eraseToVoidPublisher())
        }
        return value
    }

    // MARK: update trackable

    func update<T>(keyPath: ReferenceWritableKeyPath<Self, Trackable<T>>, _ newValue: T, forced: Bool) {
        @Ref(self, keyPath) var wrapper
        let id: Int
        if let wrapperId = wrapper.id {
            id = wrapperId
        } else {
            id = trackableIdGen.generate()
            wrapper.id = id
        }
        guard forced || wrapper.value != newValue else { return }
        let _r = subtracer.range(Tracer.StoreUpdate(trackableId: id, keyPath: keyPath)); defer { _r() }
        wrapper.value = newValue
        wrapper.didSet.send(newValue)

        if let subscriptionIds = trackableIdToSubscriptionIds.removeValue(forKey: id) {
            manager.notify(subscriptionIds: subscriptionIds)
        }

        if wrapper.willNotifyCancellable == nil {
            wrapper.willNotifyCancellable = manager.updatingWillNotify?.sink {
                let _r = subtracer.range(Tracer.StoreUpdateNotify(keyPath: keyPath, newValue: newValue)); defer { _r() }
                wrapper.willNotify.send(wrapper.value)
                wrapper.willNotifyCancellable = nil
            }
        }
    }

    // MARK: update derived

    @discardableResult func update<T>(keyPath: ReferenceWritableKeyPath<Self, Derived<T>>) -> T {
        @Ref(self, keyPath) var wrapper
        let (newValue, context) = withDeriving {
            let _r = subtracer.range(Tracer.Deriving(keyPath: keyPath)); defer { _r() }
            return wrapper.derive(self)
        }
        let _r = subtracer.range(Tracer.StoreUpdateNotify(keyPath: keyPath, newValue: newValue)); defer { _r() }

        wrapper.value = newValue
        wrapper.willNotify.send(newValue)

        wrapper.trackableIds = context.trackableIds
        wrapper.cancellables.removeAll()
        for publisher in context.publishers {
            publisher
                .sink { self.update(keyPath: keyPath) }
                .store(in: &wrapper.cancellables)
        }
        return newValue
    }
}

// MARK: Updater

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

func withStoreUpdating(_ configs: PartialSelectorConfigs = .init(), _ apply: () -> Void) {
    manager.withUpdating(configs: configs, apply)
}

// MARK: - Trackable

@propertyWrapper
struct _Trackable<Instance: _StoreProtocol, Value: Equatable> {
    fileprivate var id: Int?
    fileprivate var value: Value
    fileprivate var updatingValue: Value?

    @Passthrough<Value> fileprivate var didSet
    @Passthrough<Value> fileprivate var willNotify

    fileprivate var willNotifyCancellable: AnyCancellable?

    @available(*, unavailable, message: "@Trackable can only be applied to Store")
    var wrappedValue: Value { get { fatalError() } set { fatalError() } }

    struct Projected {
        let didSet: AnyPublisher<Value, Never>
        let willNotify: AnyPublisher<Value, Never>
    }

    var projectedValue: Projected { .init(didSet: $didSet, willNotify: $willNotify) }

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
    @Passthrough<Value> fileprivate var willNotify

    fileprivate var cancellables = Set<AnyCancellable>()

    @available(*, unavailable, message: "@Derived can only be applied to Store")
    var wrappedValue: Value { get { fatalError() } set { fatalError() } }

    struct Projected {
        let willNotify: AnyPublisher<Value, Never>
    }

    var projectedValue: Projected { .init(willNotify: $willNotify) }

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

class _Selector<Props>: ObservableObject, CancellablesHolder {
    var name: String?
    var configs: SelectorConfigs { .init() }

    var props: Props?
    var cancellables = Set<AnyCancellable>()

    var asyncNotifyTask: Task<Void, Never>?

    @Passthrough<Void> fileprivate var retrack

    required init() {}
}

private extension _Selector {
    func setup(_ name: @autoclosure () -> String, _ props: Props) {
        let name = name()
        let _r = subtracer.range(Tracer.SelectorSetup(name: name)); defer { _r() }
        self.name = name
        if self.props == nil {
            self.props = props
        }
    }

    func update(_ props: Props) {
        self.props = props
        retrack.send()
    }
}

// MARK: - SelectorProtocol

protocol _SelectorProtocol: AnyObject {
    associatedtype Props
    var name: String? { get }
    var configs: SelectorConfigs { get }
    var props: Props? { get }

    var asyncNotifyTask: Task<Void, Never>? { get set }

    func notify()
    func setupRetrack(callback: @escaping () -> Void)

    typealias Selected<T: Equatable> = _Selected<Self, T>
}

extension _Selector: _SelectorProtocol {
    func notify() {
        objectWillChange.send()
    }

    func setupRetrack(callback: @escaping () -> Void) {
        $retrack
            .sink(receiveValue: callback)
            .store(in: self)
    }
}

private extension _SelectorProtocol {
    // MARK: access selected

    func access<T>(keyPath: ReferenceWritableKeyPath<Self, Selected<T>>) -> T {
        let _r = subtracer.range(Tracer.SelectorAccess(name: name!, keyPath: keyPath)); defer { _r() }
        return self[keyPath: keyPath].value ?? track(keyPath: keyPath)
    }

    // MARK: track selected

    func configs<T>(keyPath: ReferenceWritableKeyPath<Self, Selected<T>>) -> SelectorConfigs {
        let notifyingConfigs = manager.notifyingConfigs ?? .init()
        let wrapperConfigs = self[keyPath: keyPath].configs
        let alwaysNotify = notifyingConfigs.alwaysNotify ?? wrapperConfigs.alwaysNotify ?? configs.alwaysNotify
        let syncNotify = notifyingConfigs.syncNotify ?? wrapperConfigs.syncNotify ?? configs.syncNotify
        let animation = notifyingConfigs.animation ?? wrapperConfigs.animation ?? configs.animation
        return .init(alwaysNotify: alwaysNotify, syncNotify: syncNotify, animation: animation)
    }

    @discardableResult
    func track<T>(keyPath: ReferenceWritableKeyPath<Self, Selected<T>>) -> T {
        let configs = self.configs(keyPath: keyPath)
        let _r = subtracer.range(Tracer.SelectorTrack(name: name!, keyPath: keyPath, configs: configs)); defer { _r() }
        @Ref(self, keyPath) var wrapper
        let (newValue, subscriptionId) = manager.withTracking { wrapper.selector(self.props!) } onNotify: { [weak self] in self?.track(keyPath: keyPath) }
        wrapper.subscriptionId = subscriptionId

        if wrapper.value == nil {
            wrapper.value = newValue
            setupRetrack { [weak self] in self?.retrack(keyPath: keyPath) }
            subtracer.instant(Tracer.SelectorTrackSetup(newValue: newValue))
        } else if wrapper.value != newValue || configs.alwaysNotify {
            wrapper.value = newValue
            let animation = configs.animation
            asyncNotifyTask?.cancel()
            if configs.syncNotify {
                if let animation { withAnimation(animation.animation) { notify() } } else { notify() }
            } else {
                let notifyingId = manager.notifyingId
                asyncNotifyTask = Task(priority: .high) { @MainActor [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    let _r = subtracer.range(Tracer.SelectorNotify(notifyingId: notifyingId)); defer { _r() }
                    asyncNotifyTask = nil
                    if let animation { withAnimation(animation.animation) { self.notify() } } else { self.notify() }
                }
            }
            subtracer.instant(Tracer.SelectorTrackUpdate(newValue: newValue))
        } else {
            subtracer.instant(Tracer.SelectorTrackUnchanged())
        }
        return newValue
    }

    func retrack<T>(keyPath: ReferenceWritableKeyPath<Self, Selected<T>>) {
        let _r = subtracer.range(Tracer.SelectorRetrack(name: name!, keyPath: keyPath)); defer { _r() }
        @Ref(self, keyPath) var wrapper
        if let subscriptionId = wrapper.subscriptionId {
            manager.expire(subscriptionId: subscriptionId)
        }
        track(keyPath: keyPath)
    }
}

// MARK: - Selected

@propertyWrapper
struct _Selected<Instance: _SelectorProtocol, Value: Equatable> {
    var configs: PartialSelectorConfigs
    let selector: (Instance.Props) -> Value

    var value: Value?
    var subscriptionId: Int?

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

    init(_ selector: @escaping (Instance.Props) -> Value, _ configs: PartialSelectorConfigs = .init()) {
        self.configs = configs
        self.selector = selector
    }

    init(_ selector: @escaping () -> Value, _ configs: PartialSelectorConfigs = .init()) {
        self.configs = configs
        self.selector = { _ in selector() }
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
