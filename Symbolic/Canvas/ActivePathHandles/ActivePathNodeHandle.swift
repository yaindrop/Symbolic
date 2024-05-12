import Foundation
import SwiftUI

// MARK: - ActivePathNodeHandle

struct ActivePathNodeHandle: View, EnablePathUpdater, EnablePathInteractor, EnableActivePathInteractor {
    @EnvironmentObject var viewport: ViewportModel
    @EnvironmentObject var pathModel: PathModel
    @EnvironmentObject var pendingPathModel: PendingPathModel
    @EnvironmentObject var activePathModel: ActivePathModel
    @EnvironmentObject var pathUpdateModel: PathUpdateModel

    let nodeId: UUID
    let position: Point2

    var body: some View {
        circle(at: position, color: .blue)
    }

    // MARK: private

    private static let lineWidth: Scalar = 2
    private static let circleSize: Scalar = 16
    private static let touchablePadding: Scalar = 16

    private var focused: Bool { activePathInteractor.focusedNodeId == nodeId }
    private func toggleFocus() {
        focused ? activePathInteractor.clearFocus() : activePathInteractor.setFocus(node: nodeId)
    }

    @StateObject private var dragGesture = MultipleGestureModel<Point2>()

    @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color.opacity(0.5))
            .frame(width: Self.circleSize, height: Self.circleSize)
            .if(focused) { $0.overlay {
                Circle()
                    .fill(color)
                    .scaleEffect(0.5)
                    .allowsHitTesting(false)
            }}
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .position(point)
            .multipleGesture(dragGesture, position) {
                func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
                    { pathUpdater.updateActivePath(moveNode: nodeId, offsetInView: $1.offset(to: $0.location), pending: pending) }
                }
                $0.onDrag(update(pending: true))
                $0.onDragEnd(update())
            }
    }
}
