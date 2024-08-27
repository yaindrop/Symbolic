import Combine
import Foundation

// MARK: - Ref

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

// MARK: - Getter

@propertyWrapper
struct Getter<Value> {
    let callback: () -> Value

    var wrappedValue: Value { callback() }

    init(_ callback: @escaping () -> Value) {
        self.callback = callback
    }
}

// MARK: - Passthrough

@propertyWrapper
struct Passthrough<Value> {
    let subject = PassthroughSubject<Value, Never>()
    var wrappedValue: PassthroughSubject<Value, Never> { subject }
    var projectedValue: AnyPublisher<Value, Never> { subject.eraseToAnyPublisher() }
}
