import Foundation

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
