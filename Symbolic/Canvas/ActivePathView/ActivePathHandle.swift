import Foundation
import SwiftUI

var selectBoundingRect: CGRect? { service.activePath.pendingActivePath?.boundingRect }

// MARK: - ActivePathHandle

struct ActivePathHandle: View {
    var body: some View { tracer.range("ActivePathHandle body") {
        rect
    }}

    // MARK: private

    @Selected private var boundingRect = selectBoundingRect
    @Selected private var boundingRectInView = selectBoundingRect?.applying(store.viewport.toView)

    private static let lineWidth: Scalar = 1
    private static let circleSize: Scalar = 16
    private static let touchablePadding: Scalar = 16

    @State private var dragGesture = MultipleGestureModel<Void>()

    @ViewBuilder private var rect: some View {
        if let boundingRectInView {
            Rectangle()
                .stroke(.blue, style: StrokeStyle(lineWidth: Self.lineWidth))
                .fill(.blue.opacity(0.2))
                .frame(width: boundingRectInView.width, height: boundingRectInView.height)
                .position(boundingRectInView.center)
                .multipleGesture(dragGesture, ()) {
                    func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                        { v, _ in service.pathUpdaterInView.updateActivePath(moveByOffset: Vector2(v.translation), pending: pending) }
                    }
                    $0.onDrag(update(pending: true))
                    $0.onDragEnd(update())
                }
        }
    }
}
