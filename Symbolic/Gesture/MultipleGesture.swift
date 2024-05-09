import Foundation
import SwiftUI

// MARK: - MultipleGestureModifier

struct MultipleGestureModifier<Origin>: ViewModifier {
    typealias Value = DragGesture.Value

    // MARK: Context

    struct Configs {
        var distanceThreshold: Scalar = 10 // tap or long press when smaller, drag when greater
        var durationThreshold: TimeInterval = 0.5 // tap when smaller, long press when greater
        var holdLongPressOnDrag: Bool = true // whether to continue long press after drag start
        var coordinateSpace: CoordinateSpace = .local
    }

    // MARK: Context

    private struct Context {
        let origin: Origin
        let startTime: Date = .now

        private(set) var lastValue: Value
        private(set) var maxDistance: Scalar = 0

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        mutating func onValue(_ value: Value) {
            lastValue = value
            maxDistance = max(maxDistance, value.offset.length)
        }

        init(origin: Origin, value: Value) {
            self.origin = origin
            lastValue = value
        }
    }

    // MARK: body

    func body(content: Content) -> some View {
        content
            .gesture(gesture)
            .onChange(of: active) {
                if !active {
                    onPressCancelled()
                }
            }
    }

    init(_ getOrigin: @autoclosure @escaping () -> Origin,
         configs: Configs = Configs(),
         onTap: ((Value, Origin) -> Void)? = nil,
         onLongPress: ((Value, Origin) -> Void)? = nil,
         onLongPressEnd: ((Value, Origin) -> Void)? = nil,
         onDrag: ((Value, Origin) -> Void)? = nil,
         onDragEnd: ((Value, Origin) -> Void)? = nil) {
        self.getOrigin = getOrigin
        self.configs = configs
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onLongPressEnd = onLongPressEnd
        self.onDrag = onDrag
        self.onDragEnd = onDragEnd
    }

    // MARK: private

    private let getOrigin: () -> Origin
    private let configs: Configs
    private let onTap: ((Value, Origin) -> Void)?
    private let onLongPress: ((Value, Origin) -> Void)?
    private let onLongPressEnd: ((Value, Origin) -> Void)?
    private let onDrag: ((Value, Origin) -> Void)?
    private let onDragEnd: ((Value, Origin) -> Void)?

    @State private var context: Context?
    @GestureState private var active: Bool = false

    private var isDrag: Bool {
        guard let context else { return false }
        return context.maxDistance > configs.distanceThreshold
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
        context = Context(origin: getOrigin(), value: v)
        setupLongPress()
    }

    private func onPressChanged() {
        guard let context else { return }
        if isDrag {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                resetLongPress()
            }
            onDrag?(context.lastValue, context.origin)
        }
    }

    private func onPressEnded() {
        guard let context else { return }
        let value = context.lastValue, origin = context.origin
        if isDrag {
            onDragEnd?(value, origin)
            if configs.holdLongPressOnDrag {
                resetLongPress()
            }
        } else {
            if context.longPressStarted {
                onLongPressEnd?(value, origin)
            } else {
                onTap?(value, origin)
            }
        }
    }

    private func onPressCancelled() {
        guard let context else { return }
        context.longPressTimeout?.cancel()
        self.context = nil
    }

    // MARK: long press

    private func setupLongPress() {
        guard let context else { return }
        let longPressTimeout = DispatchWorkItem {
            onLongPress?(context.lastValue, context.origin)
            self.context?.longPressStarted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
        self.context?.longPressTimeout = longPressTimeout
    }

    private func resetLongPress() {
        guard let context else { return }
        if context.longPressStarted {
            self.context?.longPressStarted = false
            onLongPressEnd?(context.lastValue, context.origin)
        }
        self.context?.longPressTimeout?.cancel()
        self.context?.longPressTimeout = nil
    }
}
