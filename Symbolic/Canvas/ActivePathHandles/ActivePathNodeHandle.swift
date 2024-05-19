import Foundation
import SwiftUI

// MARK: - ActivePathNodeHandle

struct ActivePathNodeHandle: View, EquatableBy {
    let nodeId: UUID
    let position: Point2

    var equatableBy: some Equatable { nodeId; position }

    var body: some View { tracer.range("ActivePathNodeHandle body \(nodeId)") {
        circle(at: position, color: .blue)
    }}

    init(nodeId: UUID, position: Point2) {
        self.nodeId = nodeId
        self.position = position
        _focused = .init { service.activePath.focusedNodeId == nodeId }
    }

    // MARK: private

    @Selected private var focused: Bool

    private static let lineWidth: Scalar = 2
    private static let circleSize: Scalar = 16
    private static let touchablePadding: Scalar = 16

    private func toggleFocus() {
        focused ? service.activePath.clearFocus() : service.activePath.setFocus(node: nodeId)
    }

    @State private var dragGesture = MultipleGestureModel<Point2>()

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
                    { service.pathUpdaterInView.updateActivePath(moveNode: nodeId, offset: $1.offset(to: $0.location), pending: pending) }
                }
                $0.onTap { _, _ in toggleFocus() }
                $0.onDrag(update(pending: true))
                $0.onDragEnd(update())
            }
    }
}
