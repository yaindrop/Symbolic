import Foundation
import SwiftUI

// MARK: - ActivePathHandle

struct ActivePathHandle: View {
    var body: some View {
        rect
    }

    // MARK: private

    private static let lineWidth: Scalar = 1
    private static let circleSize: Scalar = 16
    private static let touchablePadding: Scalar = 16

    @EnvironmentObject private var viewport: ViewportModel
    @EnvironmentObject private var pathModel: PathModel
    @EnvironmentObject private var activePathModel: ActivePathModel
    private var activePath: ActivePathInteractor { .init(pathModel, activePathModel) }

    @EnvironmentObject private var pathUpdateModel: PathUpdateModel
    private var updater: PathUpdater { .init(viewport, pathModel, activePathModel, pathUpdateModel) }

    @StateObject private var dragGesture = MultipleGestureModel<Void>()

    var boundingRectInView: CGRect? {
        activePath.pendingActivePath?.boundingRect.applying(viewport.toView)
    }

    @ViewBuilder private var rect: some View {
        if let boundingRectInView {
            Rectangle()
                .stroke(.blue, style: StrokeStyle(lineWidth: Self.lineWidth))
                .fill(.blue.opacity(0.2))
                .frame(width: boundingRectInView.width, height: boundingRectInView.height)
                .position(boundingRectInView.center)
                .multipleGesture(dragGesture, ()) {
                    $0.onDrag { v, _ in updater.updateActivePath(moveByOffsetInView: Vector2(v.translation), pending: true) }
                    $0.onDragEnd { v, _ in updater.updateActivePath(moveByOffsetInView: Vector2(v.translation)) }
                }
        }
    }
}
