import Foundation
import SwiftUI

// MARK: - ActivePathHandle

struct ActivePathHandle: View, EnableActivePathInteractor, EnablePathUpdaterInView {
    @Environment(ViewportModel.self) var viewport: ViewportModel
    @Environment(PathModel.self) var pathModel: PathModel
    @Environment(PendingPathModel.self) var pendingPathModel: PendingPathModel
    @Environment(ActivePathModel.self) var activePathModel: ActivePathModel
    @Environment(PathUpdateModel.self) var pathUpdateModel: PathUpdateModel

    var body: some View { tracer.range("ActivePathHandle body") {
        rect
    }}

    // MARK: private

    private static let lineWidth: Scalar = 1
    private static let circleSize: Scalar = 16
    private static let touchablePadding: Scalar = 16

    @State private var dragGesture = MultipleGestureModel<Void>()

    var boundingRectInView: CGRect? {
        activePathInteractor.pendingActivePath?.boundingRect.applying(viewport.toView)
    }

    @ViewBuilder private var rect: some View {
        if let boundingRectInView {
            Rectangle()
                .stroke(.blue, style: StrokeStyle(lineWidth: Self.lineWidth))
                .fill(.blue.opacity(0.2))
                .frame(width: boundingRectInView.width, height: boundingRectInView.height)
                .position(boundingRectInView.center)
                .multipleGesture(dragGesture, ()) {
                    func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                        { v, _ in pathUpdaterInView.updateActivePath(moveByOffset: Vector2(v.translation), pending: pending) }
                    }
                    $0.onDrag(update(pending: true))
                    $0.onDragEnd(update())
                }
        }
    }
}
