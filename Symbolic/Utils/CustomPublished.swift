import Combine
import Foundation

// MARK: - BatchedPublished

@propertyWrapper
class _BatchedPublished<Instance: ObservableObject, Value> where Instance.ObjectWillChangePublisher == ObservableObjectPublisher {
    @available(*, unavailable)
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    var projectedValue: Published<Value>.Publisher {
        get { $value }
        set { $value = newValue }
    }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: KeyPath<Instance, Value>,
        storage storageKeyPath: KeyPath<Instance, _BatchedPublished>
    ) -> Value {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            if let updatingValue = wrapper.updatingValue {
                return updatingValue
            } else {
                return wrapper.value
            }
        }
        set {
            let wrapper = instance[keyPath: storageKeyPath]
            if wrapper.updatingValue == nil {
                wrapper.value = newValue
            } else {
                wrapper.updatingValue = newValue
            }
        }
    }

    var batchUpdater: (() -> Void) -> Void {
        { [weak self] update in
            guard let self else { return }
            if self.updatingValue != nil {
                update()
                return
            }
            self.updatingValue = self.value
            update()
            self.value = self.updatingValue!
            self.updatingValue = nil
        }
    }

    init(wrappedValue initialValue: Value) {
        value = initialValue
    }

    @Published private var value: Value

    private var updatingValue: Value?
}

extension ObservableObject where Self.ObjectWillChangePublisher == ObservableObjectPublisher {
    typealias BatchedPublished<T> = _BatchedPublished<Self, T>
}

// MARK: - TracedPublished

@propertyWrapper
class _TracedPublished<Instance: ObservableObject, Value> where Instance.ObjectWillChangePublisher == ObservableObjectPublisher {
    @available(*, unavailable)
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    var projectedValue: Published<Value>.Publisher {
        get { $value }
        set { $value = newValue }
    }

    static subscript(
        _enclosingInstance instance: Instance,
        wrapped _: KeyPath<Instance, Value>,
        storage storageKeyPath: KeyPath<Instance, _TracedPublished>
    ) -> Value {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            tracer.instant("get \(wrapper.message)")
            return wrapper.value
        }
        set {
            let wrapper = instance[keyPath: storageKeyPath]
            let _r = tracer.range("set \(wrapper.message)"); defer { _r() }
            tracer.range("objectWillChange") {
                instance.objectWillChange.send()
            }
            wrapper.value = newValue
        }
    }

    init(wrappedValue: Value, _ message: String) {
        value = wrappedValue
        self.message = message
    }

    @Published private var value: Value

    private var message: String
}

extension ObservableObject where Self.ObjectWillChangePublisher == ObservableObjectPublisher {
    typealias TracedPublished<T> = _TracedPublished<Self, T>
}
