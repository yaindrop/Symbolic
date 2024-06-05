import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PathView")

// MARK: - NodeHandle

extension PathView {
    struct NodeHandle: View, EquatableBy {
        @EnvironmentObject var viewModel: PathViewModel

        let property: PathProperty
        let focusedPart: PathFocusedPart?

        let nodeId: UUID
        let position: Point2

        var nodeType: PathNodeType { property.nodeType(id: nodeId) }
        var focused: Bool { focusedPart?.nodeId == nodeId }

        var equatableBy: some Equatable { nodeId; position; nodeType; focused }

        var body: some View { subtracer.range("NodeHandle \(nodeId)") {
            handle
        }}

        // MARK: private

        private static let circleSize: Scalar = 12
        private static let rectSize: Scalar = circleSize / 2 * 1.7725 // sqrt of pi
        private static let touchablePadding: Scalar = 20

        @State private var menuSize: CGSize = .zero
        @State private var viewSize = global.viewport.store.viewSize
        @State private var nodeGestureContext = PathViewModel.NodeGestureContext()

        @ViewBuilder private var handle: some View {
            nodeShape
                .padding(Self.touchablePadding)
                .invisibleSoildOverlay()
                .position(position)
                .multipleGesture(viewModel.nodeGesture(nodeId: nodeId, context: nodeGestureContext))
        }

        @ViewBuilder private var nodeShape: some View {
            if nodeType == .corner {
                Rectangle()
                    .stroke(.blue, style: StrokeStyle(lineWidth: 1))
                    .fill(.blue.opacity(0.5))
                    .if(focused) { $0.overlay {
                        Rectangle()
                            .fill(.blue)
                            .scaleEffect(0.5)
                            .allowsHitTesting(false)
                    }}
                    .frame(width: Self.rectSize, height: Self.rectSize)
            } else {
                Circle()
                    .stroke(.blue, style: StrokeStyle(lineWidth: nodeType == .mirrored ? 2 : 1))
                    .fill(.blue.opacity(0.5))
                    .if(focused) { $0.overlay {
                        Circle()
                            .fill(.blue)
                            .scaleEffect(0.5)
                            .allowsHitTesting(false)
                    }}
                    .frame(width: Self.circleSize, height: Self.circleSize)
            }
        }
    }
}
