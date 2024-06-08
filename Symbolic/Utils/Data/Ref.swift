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
