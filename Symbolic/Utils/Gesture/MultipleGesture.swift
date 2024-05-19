import Combine
import Foundation
import SwiftUI

// MARK: - MultipleGestureModel

class MultipleGestureModel<Data> {
    typealias Value = DragGesture.Value

    // MARK: Configs

    struct Configs {
        var distanceThreshold: Scalar = 10 // tap or long press when smaller, drag when greater
        var durationThreshold: TimeInterval = 0.5 // tap when smaller, long press when greater
        var holdLongPressOnDrag: Bool = true // whether to continue long press after drag start
        var coordinateSpace: CoordinateSpace = .local
    }

    func onTap(_ callback: @escaping (Value, Data) -> Void) {
        tapSubject.compactMap(makeValue).sink(receiveValue: callback).store(in: &subscriptions)
    }

    func onLongPress(_ callback: @escaping (Value, Data) -> Void) {
        longPressSubject.compactMap(makeValue).sink(receiveValue: callback).store(in: &subscriptions)
    }

    func onLongPressEnd(_ callback: @escaping (Value, Data) -> Void) {
        longPressEndSubject.compactMap(makeValue).sink(receiveValue: callback).store(in: &subscriptions)
    }

    func onDrag(_ callback: @escaping (Value, Data) -> Void) {
        dragSubject.compactMap(makeValue).sink(receiveValue: callback).store(in: &subscriptions)
    }

    func onDragEnd(_ callback: @escaping (Value, Data) -> Void) {
        dragEndSubject.compactMap(makeValue).sink(receiveValue: callback).store(in: &subscriptions)
    }

    init(configs: Configs = Configs()) {
        self.configs = configs
    }

    // MARK: fileprivate

    fileprivate struct Context {
        let data: Data
        let startTime: Date = .now

        private(set) var lastValue: Value
        private(set) var maxDistance: Scalar = 0

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        mutating func onValue(_ value: Value) {
            lastValue = value
            maxDistance = max(maxDistance, value.offset.length)
        }

        init(data: Data, value: Value) {
            self.data = data
            lastValue = value
        }
    }

    fileprivate let configs: Configs

    fileprivate var context: Context?
    fileprivate var subscriptions = Set<AnyCancellable>()

    fileprivate let tapSubject = PassthroughSubject<Void, Never>()
    fileprivate let longPressSubject = PassthroughSubject<Void, Never>()
    fileprivate let longPressEndSubject = PassthroughSubject<Void, Never>()
    fileprivate let dragSubject = PassthroughSubject<Void, Never>()
    fileprivate let dragEndSubject = PassthroughSubject<Void, Never>()

    private var makeValue: () -> (Value, Data)? {
        { if let context = self.context { (context.lastValue, context.data) } else { nil } }
    }
}

// MARK: - MultipleGestureModifier

struct MultipleGestureModifier<Data>: ViewModifier {
    func body(content: Content) -> some View {
        content
            .gesture(gesture)
            .onChange(of: active) {
                if !active {
                    onPressCancelled()
                }
            }
    }

    init(_ model: MultipleGestureModel<Data>, _ getData: @autoclosure @escaping () -> Data) {
        self.model = model
        self.getData = getData
    }

    // MARK: private

    private let model: MultipleGestureModel<Data>

    private var configs: MultipleGestureModel<Data>.Configs { model.configs }

    private var context: MultipleGestureModel<Data>.Context? {
        get { model.context }
        nonmutating set { model.context = newValue }
    }

    private let getData: () -> Data
    @GestureState private var active: Bool = false

    private var isPress: Bool {
        guard let context else { return false }
        return context.maxDistance < configs.distanceThreshold
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: configs.coordinateSpace)
            .updating(flag: $active)
            .onChanged { v in
                if context == nil {
                    onPressStarted(v)
                    onPressChanged()
                } else {
                    context?.onValue(v)
                    onPressChanged()
                }
            }
            .onEnded { v in
                context?.onValue(v)
                onPressEnded()
            }
    }

    // MARK: stages

    private func onPressStarted(_ v: DragGesture.Value) {
        context = .init(data: getData(), value: v)
        setupLongPress()
    }

    private func onPressChanged() {
        guard let context else { return }
        if !isPress {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                resetLongPress()
            }
            model.dragSubject.send()
        }
    }

    private func onPressEnded() {
        guard let context else { return }
        if isPress {
            if context.longPressStarted {
                model.longPressEndSubject.send()
            } else {
                model.tapSubject.send()
            }
        } else {
            model.dragEndSubject.send()
            if configs.holdLongPressOnDrag {
                resetLongPress()
            }
        }
    }

    private func onPressCancelled() {
        resetLongPress()
        context = nil
    }

    // MARK: long press

    private func setupLongPress() {
        guard context != nil else { return }
        let longPressTimeout = DispatchWorkItem {
            model.longPressSubject.send()
            self.context?.longPressStarted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
        context?.longPressTimeout = longPressTimeout
    }

    private func resetLongPress() {
        guard let context else { return }
        if let timeout = context.longPressTimeout {
            self.context?.longPressTimeout = nil
            timeout.cancel()
        }
        if context.longPressStarted {
            self.context?.longPressStarted = false
            model.longPressEndSubject.send()
        }
    }
}

extension View {
    func multipleGesture<Data>(_ model: MultipleGestureModel<Data>, _ getData: @autoclosure @escaping () -> Data, _ setup: ((MultipleGestureModel<Data>) -> Void)? = nil) -> some View {
        modifier(MultipleGestureModifier<Data>(model, getData()))
            .onAppear { setup?(model) }
    }
}
