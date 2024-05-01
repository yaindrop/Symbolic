import Foundation
import SwiftUI

// MARK: - DragGestureWithContext

struct DragGestureWithContext<Context>: ViewModifier {
    func body(content: Content) -> some View {
        content
            .gesture(gesture)
            .onChange(of: dragging) {
                if !dragging {
                    context = nil
                }
            }
    }

    init(_ getContext: @autoclosure @escaping () -> Context,
         onChanged: @escaping (DragGesture.Value, Context) -> Void,
         onEnded: @escaping (DragGesture.Value, Context) -> Void) {
        self.getContext = getContext
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    private let getContext: () -> Context
    private let onChanged: (DragGesture.Value, Context) -> Void
    private let onEnded: (DragGesture.Value, Context) -> Void

    @State private var context: Context?
    @GestureState private var dragging: Bool = false

    private var gesture: some Gesture {
        DragGesture()
            .updating(flag: $dragging)
            .onChanged { value in
                if let context {
                    onChanged(value, context)
                } else {
                    let context = getContext()
                    self.context = context
                    onChanged(value, context)
                }
            }
            .onEnded { value in
                if let context {
                    onEnded(value, context)
                }
            }
    }
}

// MARK: - TapLongPressDrag

struct TapLongPressDrag: ViewModifier {
    class Context {
        var inited = false
        var startTime: Date = .now

        var maxOffsetLength: CGFloat = 0
        var lastLocation: Point2 = .zero

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        func setup() {
            guard !inited else { return }
            inited = true
            startTime = .now

            maxOffsetLength = 0
            lastLocation = .zero

            longPressTimeout = nil
            longPressStarted = false
        }

        func update(value: DragGesture.Value) {
            lastLocation = value.location
            let offset = Vector2(value.translation)
            if offset.length > maxOffsetLength {
                maxOffsetLength = offset.length
            }
        }

        func reset() {
            inited = false
            longPressTimeout?.cancel()
        }
    }

    struct Configs {
        let distanceThreshold: CGFloat = 10 // tap or long press when smaller, drag when greater
        let durationThreshold: TimeInterval = 1 // tap when smaller, long press when greater
    }

    func body(content: Content) -> some View {
        content
            .gesture(gesture)
            .onChange(of: active) {
                if active {
                    setupLongPress()
                } else {
                    context.reset()
                }
            }
    }

    init(configs: Configs = Configs(),
         onTap: @escaping (Point2) -> Void = { _ in },
         onLongPress: @escaping (Point2) -> Void = { _ in },
         onLongPressEnd: @escaping (Point2) -> Void = { _ in },
         onDrag: @escaping (Vector2) -> Void = { _ in },
         onDragEnd: @escaping (Vector2) -> Void = { _ in }) {
        self.configs = configs
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onLongPressEnd = onLongPressEnd
        self.onDrag = onDrag
        self.onDragEnd = onDragEnd
    }

    // MARK: private

    private let configs: Configs
    private let onTap: (Point2) -> Void
    private let onLongPress: (Point2) -> Void
    private let onLongPressEnd: (Point2) -> Void
    private let onDrag: (Vector2) -> Void
    private let onDragEnd: (Vector2) -> Void

    private var context: Context = Context()
    @GestureState private var active: Bool = false

    private var isDrag: Bool { context.maxOffsetLength > configs.distanceThreshold }

    private func setupLongPress() {
        let longPressTimeout = DispatchWorkItem {
            onLongPress(context.lastLocation)
            context.longPressStarted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
        context.longPressTimeout = longPressTimeout
    }

    private func resetLongPress() {
        if context.longPressStarted {
            onLongPressEnd(context.lastLocation)
        }
        if let timeout = context.longPressTimeout {
            timeout.cancel()
            context.longPressTimeout = nil
        }
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(flag: $active)
            .onChanged { v in
                context.setup()
                context.update(value: v)
                if isDrag {
                    resetLongPress()
                    onDrag(Vector2(v.translation))
                }
            }
            .onEnded { v in
                context.update(value: v)
                if isDrag {
                    onDragEnd(Vector2(v.translation))
                } else {
                    if context.longPressStarted {
                        onLongPressEnd(v.location)
                    } else {
                        onTap(v.location)
                    }
                }
            }
    }
}
