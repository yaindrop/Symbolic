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

class TapDragPressContext: ObservableObject {
    var inited = false
    var startTime: Date = .now
    var maxOffsetLength: CGFloat = 0

    var lastLocation: Point2 = .zero
    var longPressTimeout: DispatchWorkItem?

    func setup() {
        inited = true
        startTime = .now
        maxOffsetLength = 0
        longPressTimeout = nil
    }

    func reset() {
        inited = false
        longPressTimeout?.cancel()
    }
}

struct TapDragPress: ViewModifier {
    struct Configs {
        let distanceThreshold: CGFloat = 10 // tap or long press when smaller, drag when greater
        let durationThreshold: TimeInterval = 1 // tap when smaller, long press when greater
    }

    let configs = Configs()

    func body(content: Content) -> some View {
        content
            .gesture(gesture)
            .onChange(of: active) {
//                print("active", active)
                if active {
                    let longPressTimeout = DispatchWorkItem {
                        onLongPress(context.lastLocation)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
                    context.longPressTimeout = longPressTimeout
                } else {
                    context.reset()
                }
            }
    }

    @StateObject private var context: TapDragPressContext = TapDragPressContext()
    @GestureState private var active: Bool = false

    private let onTap: (Point2) -> Void = { print("onTap", $0) }
    private let onLongPress: (Point2) -> Void = { print("onLongPress", $0) }
    private let onLongPressEnd: (Point2) -> Void = { print("onLongPressEnd", $0) }
    private let onDrag: (Vector2) -> Void = { print("onDrag", $0) }
    private let onDragEnd: (Vector2) -> Void = { print("onDragEnd", $0) }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating(flag: $active)
            .onChanged { v in
//                print("onChanged", v)
                if !context.inited {
                    context.setup()
                }
                // update context
                context.lastLocation = v.location
                let offset = Vector2(v.translation)
                if offset.length > context.maxOffsetLength {
                    context.maxOffsetLength = offset.length
                }
                // press or drag
                if context.maxOffsetLength < configs.distanceThreshold {
                } else {
                    if let timeout = context.longPressTimeout {
                        timeout.cancel()
                        context.longPressTimeout = nil
                    }
                    onDrag(offset)
                }
            }
            .onEnded { v in
//                print("onEnded", v)
                // update context
                context.lastLocation = v.location
                let offset = Vector2(v.translation)
                if offset.length > context.maxOffsetLength {
                    context.maxOffsetLength = offset.length
                }
                // end
                if context.maxOffsetLength < configs.distanceThreshold {
                    if Date.now.timeIntervalSince(context.startTime) < configs.durationThreshold {
                        onTap(v.location)
                    } else {
                        onLongPressEnd(v.location)
                    }
                } else {
                    onDragEnd(offset)
                }
            }
    }
}
