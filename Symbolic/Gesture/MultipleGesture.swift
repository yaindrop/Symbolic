import Foundation
import SwiftUI

// MARK: - MultipleGestureModifier

struct MultipleGestureModifier<ExternalContext>: ViewModifier {
    struct Configs {
        let distanceThreshold: CGFloat = 10 // tap or long press when smaller, drag when greater
        let durationThreshold: TimeInterval = 1 // tap when smaller, long press when greater
    }

    struct Context {
        let externalContext: ExternalContext
        let startTime: Date = .now

        private(set) var lastValue: DragGesture.Value
        private(set) var maxDistance: CGFloat = 0

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        mutating func onValue(_ value: DragGesture.Value) {
            lastValue = value
            maxDistance = max(maxDistance, Vector2(value.translation).length)
        }

        init(externalContext: ExternalContext, value: DragGesture.Value) {
            self.externalContext = externalContext
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

    init(_ getExternalContext: @autoclosure @escaping () -> ExternalContext,
         configs: Configs = Configs(),
         onTap: @escaping (DragGesture.Value, ExternalContext) -> Void = { _, _ in },
         onLongPress: @escaping (DragGesture.Value, ExternalContext) -> Void = { _, _ in },
         onLongPressEnd: @escaping (DragGesture.Value, ExternalContext) -> Void = { _, _ in },
         onDrag: @escaping (DragGesture.Value, ExternalContext) -> Void = { _, _ in },
         onDragEnd: @escaping (DragGesture.Value, ExternalContext) -> Void = { _, _ in }) {
        self.getExternalContext = getExternalContext
        self.configs = configs
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onLongPressEnd = onLongPressEnd
        self.onDrag = onDrag
        self.onDragEnd = onDragEnd
    }

    // MARK: private

    private let getExternalContext: () -> ExternalContext
    private let configs: Configs
    private let onTap: (DragGesture.Value, ExternalContext) -> Void
    private let onLongPress: (DragGesture.Value, ExternalContext) -> Void
    private let onLongPressEnd: (DragGesture.Value, ExternalContext) -> Void
    private let onDrag: (DragGesture.Value, ExternalContext) -> Void
    private let onDragEnd: (DragGesture.Value, ExternalContext) -> Void

    @State private var context: Context?
    @GestureState private var active: Bool = false

    private var isDrag: Bool {
        guard let context else { return false }
        return context.maxDistance > configs.distanceThreshold
    }

    private func setupLongPress() {
        guard let context else { return }
        let longPressTimeout = DispatchWorkItem {
            onLongPress(context.lastValue, context.externalContext)
            self.context?.longPressStarted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
        self.context?.longPressTimeout = longPressTimeout
    }

    private func resetLongPress() {
        guard let context else { return }
        if context.longPressStarted {
            self.context?.longPressStarted = false
            onLongPressEnd(context.lastValue, context.externalContext)
        }
        self.context?.longPressTimeout?.cancel()
        self.context?.longPressTimeout = nil
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(flag: $active)
            .onChanged { v in
                context?.onValue(v)
                if context == nil {
                    context = Context(externalContext: getExternalContext(), value: v)
                    setupLongPress()
                }
                guard let context else { return }
                if isDrag {
                    resetLongPress()
                    onDrag(v, context.externalContext)
                }
            }
            .onEnded { v in
                context?.onValue(v)
                guard let context else { return }
                if isDrag {
                    onDragEnd(v, context.externalContext)
                } else if context.longPressStarted {
                    onLongPressEnd(v, context.externalContext)
                } else {
                    onTap(v, context.externalContext)
                }
            }
    }
}
