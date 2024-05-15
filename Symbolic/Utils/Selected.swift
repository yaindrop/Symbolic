import Foundation
import SwiftUI

// MARK: - Selected

@propertyWrapper
struct Selected<Value: Equatable>: DynamicProperty {
    private class Storage: ObservableObject {
        var wrappedValue: Value {
            if let value {
                return value
            }
            setupSelectTask()
            return selector()
        }

        init(selector: @escaping () -> Value) {
            self.selector = selector
        }

        deinit {
            selectTask?.cancel()
        }

        private let selector: () -> Value
        private var value: Value?
        private var selectTask: Task<Void, Never>?

        private func setupSelectTask() {
            selectTask = Task { @MainActor [weak self] in
                self?.select()
            }
        }

        private func select() {
            withObservationTracking {
                let newValue = selector()
                if value != newValue {
                    objectWillChange.send()
                }
                value = newValue
            } onChange: { [weak self] in
                self?.setupSelectTask()
            }
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value { storage.wrappedValue }

    var projectedValue: Selected<Value> { self }

    init(_ selector: @escaping () -> Value) {
        _storage = StateObject(wrappedValue: Storage(selector: selector))
    }

    init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.init(wrappedValue)
    }
}
