import Foundation
import SwiftUI

// MARK: - ActivePathNodeHandle

struct ActivePathNodeHandle: View {
    let nodeId: UUID
    let position: Point2

    var body: some View {
        circle(at: position, color: .blue)
    }

    // MARK: private

    private static let lineWidth: CGFloat = 2
    private static let circleSize: CGFloat = 16
    private static let touchablePadding: CGFloat = 16

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    private var focused: Bool { activePathModel.focusedNodeId == nodeId }
    private func toggleFocus() {
        activePathModel.focusedPart = focused ? nil : .node(nodeId)
    }

    @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color.opacity(0.5))
            .frame(width: Self.circleSize, height: Self.circleSize)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .position(point)
            .modifier(drag)
            .onTapGesture {
                toggleFocus()
            }
    }

    private var drag: MultipleGestureModifier<Point2> {
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { value, origin in updater.updateActivePath(moveNode: nodeId, offsetInView: origin.deltaVector(to: value.location), pending: pending) }
        }
        return MultipleGestureModifier(position, onDrag: update(pending: true), onDragEnd: update())
    }
}
