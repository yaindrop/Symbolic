import SwiftUI

private let subtracer = tracer.tagged("MultipleGesture")

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

    var onPress: (() -> Void)?
    var onPressEnd: ((_ cancelled: Bool) -> Void)?

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
                    onPressCancel()
                }
            }
            .onDisappear {
                onPressCancel()
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
                    onPressStart(v)
                    onPressChange()
                } else {
                    context?.onValue(v)
                    onPressChange()
                }
            }
            .onEnded { v in
                context?.onValue(v)
                onPressEnd()
            }
    }

    // MARK: stages

    private func onPressStart(_ v: DragGesture.Value) {
        let _r = subtracer.range(type: .intent, "press start"); defer { _r() }
        context = .init(value: v)
        setupLongPress()
        gesture.onPress?()
    }

    private func onPressChange() {
        guard let context else { return }
        let _r = subtracer.range(type: .intent, "press change"); defer { _r() }
        if !isPress {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                resetLongPress()
            }
            gesture.onDrag?(context.lastValue)
        }
    }

    private func onPressEnd() {
        guard let context else { return }
        let _r = subtracer.range(type: .intent, "press end"); defer { _r() }
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
        gesture.onPressEnd?(false)
        self.context = nil
    }

    private func onPressCancel() {
        guard context != nil else { return }
        let _r = subtracer.range(type: .intent, "press cancel"); defer { _r() }
        resetLongPress(cancel: true)
        gesture.onPressEnd?(true)
        context = nil
    }

    // MARK: long press

    private func setupLongPress() {
        guard let context else { return }
        let _r = subtracer.range("setup long press"); defer { _r() }
        let longPressTimeout = DispatchWorkItem {
            gesture.onLongPress?(context.lastValue)
            self.context?.longPressStarted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
        self.context?.longPressTimeout = longPressTimeout
    }

    private func resetLongPress(cancel: Bool = false) {
        guard let context else { return }
        if let timeout = context.longPressTimeout {
            let _r = subtracer.range("reset long press timeout"); defer { _r() }
            self.context?.longPressTimeout = nil
            timeout.cancel()
        }
        if context.longPressStarted {
            let _r = subtracer.range("\(cancel ? "cancel" : "end") long press"); defer { _r() }
            self.context?.longPressStarted = false
            if !cancel {
                gesture.onLongPressEnd?(context.lastValue)
            }
        }
    }
}

extension View {
    func multipleGesture(_ gesture: MultipleGesture) -> some View {
        modifier(MultipleGestureModifier(gesture: gesture))
    }

    func multipleGesture(_ gesture: MultipleGesture?) -> some View {
        self.if(gesture) { $0.modifier(MultipleGestureModifier(gesture: $1)) }
    }
}
