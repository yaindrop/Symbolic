import Foundation

@propertyWrapper
class Boxed<Value> {
    var wrappedValue: Value

    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
