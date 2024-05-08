import Foundation
import SwiftUI

// MARK: - MultipleGestureModifier

struct MultipleGestureModifier<Origin>: ViewModifier {
    typealias Value = DragGesture.Value

    struct Configs {
        var distanceThreshold: Scalar = 10 // tap or long press when smaller, drag when greater
        var durationThreshold: TimeInterval = 0.5 // tap when smaller, long press when greater
        var allowLongPressDuringDrag: Bool = true // whether to continue long press after drag start
        var coordinateSpace: CoordinateSpace = .local
    }

    private struct Context {
        let origin: Origin
        let startTime: Date = .now

        private(set) var lastValue: Value
        private(set) var maxDistance: Scalar = 0

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        mutating func onValue(_ value: Value) {
            lastValue = value
            maxDistance = max(maxDistance, Vector2(value.translation).length)
        }

        init(origin: Origin, value: Value) {
            self.origin = origin
            lastValue = value
        }
    }

    func body(content: Content) -> some View {
        content
            .gesture(gesture)
            .onChange(of: active) {
                if !active {
                    context?.longPressTimeout?.cancel()
                    context = nil
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

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: configs.coordinateSpace)
            .updating(flag: $active)
            .onChanged { v in
                context?.onValue(v)
                if context == nil {
                    context = Context(origin: getOrigin(), value: v)
                    setupLongPress()
                }
                guard let context else { return }
                if isDrag {
                    if !context.longPressStarted || !configs.allowLongPressDuringDrag {
                        resetLongPress()
                    }
                    onDrag?(v, context.origin)
                }
            }
            .onEnded { v in
                context?.onValue(v)
                guard let context else { return }
                if isDrag {
                    onDragEnd?(v, context.origin)
                    if context.longPressStarted && configs.allowLongPressDuringDrag {
                        onLongPressEnd?(v, context.origin)
                    }
                } else {
                    if context.longPressStarted {
                        onLongPressEnd?(v, context.origin)
                    } else {
                        onTap?(v, context.origin)
                    }
                }
            }
    }
}
