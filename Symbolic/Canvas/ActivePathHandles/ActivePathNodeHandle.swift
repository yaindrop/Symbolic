import Foundation
import SwiftUI

// MARK: - ActivePathNodeHandle

struct ActivePathNodeHandle: View {
    let segment: PathSegment
    let data: PathSegmentData

    var body: some View {
        circle(at: data.node, color: .blue)
    }

    // MARK: private

    private static let lineWidth: CGFloat = 2
    private static let circleSize: CGFloat = 16
    private static let touchablePadding: CGFloat = 16

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    private var nodeId: UUID { segment.node.id }

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

    private var drag: DragGestureWithContext<Point2> {
        DragGestureWithContext {
            data.node
        } onChanged: { value, origin in
            updater.updateActivePath(aroundNode: nodeId, offsetInView: origin.deltaVector(to: value.location), pending: true)
        } onEnded: { value, origin in
            updater.updateActivePath(aroundNode: nodeId, offsetInView: origin.deltaVector(to: value.location))
        }
    }
}
