import Foundation
import SwiftUI

// MARK: - Observed

@propertyWrapper
struct Observed<Value: Equatable>: DynamicProperty {
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
            setupSelectTask()
        }

        deinit {
            selectTask?.cancel()
        }

        private let selector: () -> Value
        @Published private var value: Value?
        private var selectTask: Task<Void, Never>?

        private func setupSelectTask() {
            selectTask?.cancel()
            selectTask = Task { @MainActor [weak self] in
                self?.select()
            }
        }

        private func select() {
            withObservationTracking {
                let newValue = selector()
                if value != newValue {
                    value = newValue
                }
            } onChange: { [weak self] in
                self?.setupSelectTask()
            }
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value { storage.wrappedValue }

    var projectedValue: Observed<Value> { self }

    init(_ selector: @escaping () -> Value) {
        _storage = StateObject(wrappedValue: Storage(selector: selector))
    }

    init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.init(wrappedValue)
    }
}
