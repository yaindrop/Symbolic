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

    private static let lineWidth: Scalar = 2
    private static let circleSize: Scalar = 16
    private static let touchablePadding: Scalar = 16

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    private var focused: Bool { activePathModel.focusedNodeId == nodeId }
    private func toggleFocus() {
        focused ? activePathModel.clearFocus() : activePathModel.setFocus(node: nodeId)
    }

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
            .modifier(gesture)
    }

    private var gesture: some ViewModifier {
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { value, origin in updater.updateActivePath(moveNode: nodeId, offsetInView: origin.offset(to: value.location), pending: pending) }
        }
        return MultipleGestureModifier(position, onTap: { _, _ in toggleFocus() }, onDrag: update(pending: true), onDragEnd: update())
    }
}
