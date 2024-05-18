import Foundation

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

@propertyWrapper
struct Ref<Instance, Value> {
    let instance: Instance
    let keypath: ReferenceWritableKeyPath<Instance, Value>

    var wrappedValue: Value {
        get { instance[keyPath: keypath] }
        nonmutating set { instance[keyPath: keypath] = newValue }
    }

    init(_ instance: Instance, _ keypath: ReferenceWritableKeyPath<Instance, Value>) {
        self.instance = instance
        self.keypath = keypath
    }
}
