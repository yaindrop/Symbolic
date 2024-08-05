import SwiftUI

// MARK: - ThrottledState

@propertyWrapper
struct ThrottledState<Value>: DynamicProperty {
    struct Configs {
        var duration: Double
        var leading: Bool = true
        var trailing: Bool = true
    }

    private class Storage: ObservableObject {
        @Published var value: Value

        private let configs: Configs
        private var throttledValue: Value?
        private var task: Task<Void, Never>?

        func on(newValue: Value) {
            if task == nil {
                throttleStart(newValue)
            } else {
                throttledValue = newValue
            }
        }

        func throttleStart(_ newValue: Value) {
            if configs.leading {
                value = newValue
            } else {
                throttledValue = newValue
            }
            setupTask()
        }

        func setupTask() {
            task?.cancel()
            task = Task.delayed(seconds: configs.duration) { @MainActor [weak self] in
                self?.throttleEnd()
            }
        }

        func throttleEnd() {
            task?.cancel()
            task = nil
            if configs.trailing, let throttledValue {
                value = throttledValue
            }
        }

        init(value: Value, configs: Configs) {
            self.value = value
            self.configs = configs
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.on(newValue: newValue) }
    }

    func throttleEnd() { storage.throttleEnd() }

    init(wrappedValue: Value, configs: Configs) {
        _storage = .init(wrappedValue: .init(value: wrappedValue, configs: configs))
    }
}

// MARK: - DelayedState

@propertyWrapper
struct DelayedState<Value>: DynamicProperty {
    struct Configs {
        var duration: Double
    }

    private class Storage: ObservableObject {
        @Published var value: Value

        private let configs: Configs
        private var delayedValue: Value?
        private var task: DispatchWorkItem?

        func on(newValue: Value) {
            delayedValue = newValue
            setupTask()
        }

        func setupTask() {
            task?.cancel()
            let task = DispatchWorkItem { [weak self] in
                guard let self else { return }
                delayEnd()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + configs.duration, execute: task)
            self.task = task
        }

        func delayEnd() {
            task?.cancel()
            task = nil
            if let delayedValue {
                value = delayedValue
            }
        }

        init(value: Value, configs: Configs) {
            self.value = value
            self.configs = configs
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.on(newValue: newValue) }
    }

    func delayEnd() { storage.delayEnd() }

    init(wrappedValue: Value, configs: Configs) {
        _storage = .init(wrappedValue: .init(value: wrappedValue, configs: configs))
    }
}

// MARK: - AutoResetState

@propertyWrapper
struct AutoResetState<Value>: DynamicProperty {
    struct Configs {
        var duration: Double
    }

    private class Storage: ObservableObject {
        @Published var value: Value?

        private let configs: Configs
        private var task: DispatchWorkItem?

        func on(newValue: Value?) {
            value = newValue
            setupTask()
        }

        func setupTask() {
            task?.cancel()
            let task = DispatchWorkItem { [weak self] in
                guard let self else { return }
                value = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + configs.duration, execute: task)
            self.task = task
        }

        init(configs: Configs) {
            self.configs = configs
        }
    }

    @StateObject private var storage: Storage

    var wrappedValue: Value? {
        get { storage.value }
        nonmutating set { storage.on(newValue: newValue) }
    }

    init(configs: Configs) {
        _storage = .init(wrappedValue: .init(configs: configs))
    }
}
