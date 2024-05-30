import Foundation
import SwiftUI

// MARK: - Configs

struct MultipleGestureConfigs {
    var distanceThreshold: Scalar = 10 // tap or long press when smaller, drag when greater
    var durationThreshold: TimeInterval = 0.5 // tap when smaller, long press when greater
    var holdLongPressOnDrag: Bool = true // whether to continue long press after drag start
    var coordinateSpace: CoordinateSpace = .local
}

// MARK: - MultipleGesture

struct MultipleGesture<Data> {
    typealias Value = DragGesture.Value

    var configs: MultipleGestureConfigs = .init()

    var onTouchDown: (() -> Void)?
    var onTouchUp: (() -> Void)?

    var onTap: ((Value, Data) -> Void)?
    var onLongPress: ((Value, Data) -> Void)?
    var onLongPressEnd: ((Value, Data) -> Void)?
    var onDrag: ((Value, Data) -> Void)?
    var onDragEnd: ((Value, Data) -> Void)?
}

// MARK: - Context

private struct MultipleGestureContext<Data> {
    typealias Value = DragGesture.Value

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

// MARK: - MultipleGestureModifier

struct MultipleGestureModifier<Data>: ViewModifier {
    typealias Value = DragGesture.Value

    let getData: () -> Data
    let gesture: MultipleGesture<Data>

    func body(content: Content) -> some View {
        content
            .gesture(dragGesture)
            .onChange(of: active) {
                if !active {
                    onPressCancelled()
                }
            }
    }

    // MARK: private

    @State private var context: MultipleGestureContext<Data>?
    private var configs: MultipleGestureConfigs { gesture.configs }

    @GestureState private var active: Bool = false

    private var isPress: Bool {
        guard let context else { return false }
        return context.maxDistance < configs.distanceThreshold
    }

    private var dragGesture: some Gesture {
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
        gesture.onTouchDown?()
    }

    private func onPressChanged() {
        guard let context else { return }
        if !isPress {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                resetLongPress()
            }
            gesture.onDrag?(context.lastValue, context.data)
        }
    }

    private func onPressEnded() {
        guard let context else { return }
        if isPress {
            resetLongPress()
            if !context.longPressStarted {
                gesture.onTap?(context.lastValue, context.data)
            }
        } else {
            gesture.onDragEnd?(context.lastValue, context.data)
            if configs.holdLongPressOnDrag {
                resetLongPress()
            }
        }
        gesture.onTouchUp?()
        self.context = nil
    }

    private func onPressCancelled() {
        resetLongPress()
        gesture.onTouchUp?()
        context = nil
    }

    // MARK: long press

    private func setupLongPress() {
        guard let context else { return }
        let longPressTimeout = DispatchWorkItem {
            gesture.onLongPress?(context.lastValue, context.data)
            self.context?.longPressStarted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
        self.context?.longPressTimeout = longPressTimeout
    }

    private func resetLongPress() {
        guard let context else { return }
        if let timeout = context.longPressTimeout {
            self.context?.longPressTimeout = nil
            timeout.cancel()
        }
        if context.longPressStarted {
            self.context?.longPressStarted = false
            gesture.onLongPressEnd?(context.lastValue, context.data)
        }
    }
}

// MARK: - extension

extension MultipleGestureModifier {
    init(_ getData: @autoclosure @escaping () -> Data, _ gesture: MultipleGesture<Data> = .init()) {
        self.init(getData: getData, gesture: gesture)
    }
}

extension MultipleGestureModifier where Data == Void {
    init(_ gesture: MultipleGesture<Data> = .init()) {
        self.init(getData: {}, gesture: gesture)
    }
}

extension View {
    func multipleGesture<Data>(_ getData: @autoclosure @escaping () -> Data, _ gesture: MultipleGesture<Data>) -> some View {
        modifier(MultipleGestureModifier<Data>(getData: getData, gesture: gesture))
    }

    func multipleGesture(_ gesture: MultipleGesture<Void>) -> some View {
        modifier(MultipleGestureModifier<Void>(getData: {}, gesture: gesture))
    }
}
