import Foundation
import SwiftUI

fileprivate let subtracer = tracer.tagged("PathView")

extension PathView {
    // MARK: - NodeHandle

    struct NodeHandle: View, EquatableBy {
        @EnvironmentObject var viewModel: PathViewModel

        let nodeId: UUID
        let position: Point2
        let focusedPart: PathFocusedPart?

        var focused: Bool { focusedPart?.nodeId == nodeId }

        var equatableBy: some Equatable { nodeId; position; focused }

        var body: some View { subtracer.range("NodeHandle \(nodeId)") {
            circle(at: position, color: .blue)
        }}

        // MARK: private

        private static let lineWidth: Scalar = 2
        private static let circleSize: Scalar = 16
        private static let touchablePadding: Scalar = 16

        @State private var gesture: MultipleGestureModel<Point2>?
        @State private var gestureContext: PathViewModel.NodeGestureContext?

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
                .if(gesture) {
                    $0.multipleGesture($1, position)
                }
                .onAppear {
                    let pair = viewModel.nodeGesture(nodeId: nodeId)
                    gesture = pair?.0
                    gestureContext = pair?.1
                }
        }
    }
}
