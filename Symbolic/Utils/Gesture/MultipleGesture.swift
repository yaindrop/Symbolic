import Foundation
import SwiftUI

// MARK: - MultipleGesture

struct MultipleGesture {
    typealias Value = DragGesture.Value

    struct Configs {
        var distanceThreshold: Scalar = 10 // tap or long press when smaller, drag when greater
        var durationThreshold: TimeInterval = 0.5 // tap when smaller, long press when greater
        var holdLongPressOnDrag: Bool = true // whether to continue long press after drag start
        var coordinateSpace: CoordinateSpace = .local
    }

    var configs: Configs = .init()

    var onTouchDown: (() -> Void)?
    var onTouchUp: (() -> Void)?

    var onTap: ((Value) -> Void)?
    var onLongPress: ((Value) -> Void)?
    var onLongPressEnd: ((Value) -> Void)?
    var onDrag: ((Value) -> Void)?
    var onDragEnd: ((Value) -> Void)?
}

// MARK: - MultipleGestureModifier

struct MultipleGestureModifier: ViewModifier {
    typealias Value = DragGesture.Value

    let gesture: MultipleGesture

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

    private struct Context {
        let startTime: Date = .now

        private(set) var lastValue: Value
        private(set) var maxDistance: Scalar = 0

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        mutating func onValue(_ value: Value) {
            lastValue = value
            maxDistance = max(maxDistance, value.offset.length)
        }

        init(value: Value) {
            lastValue = value
        }
    }

    @State private var context: Context?

    @GestureState private var active: Bool = false

    private var configs: MultipleGesture.Configs { gesture.configs }

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
        context = .init(value: v)
        setupLongPress()
        gesture.onTouchDown?()
    }

    private func onPressChanged() {
        guard let context else { return }
        if !isPress {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                resetLongPress()
            }
            gesture.onDrag?(context.lastValue)
        }
    }

    private func onPressEnded() {
        guard let context else { return }
        if isPress {
            resetLongPress()
            if !context.longPressStarted {
                gesture.onTap?(context.lastValue)
            }
        } else {
            gesture.onDragEnd?(context.lastValue)
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
            gesture.onLongPress?(context.lastValue)
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
            gesture.onLongPressEnd?(context.lastValue)
        }
    }
}

extension View {
    func multipleGesture(_ gesture: MultipleGesture) -> some View {
        modifier(MultipleGestureModifier(gesture: gesture))
    }
}
