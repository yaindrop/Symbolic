import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PathView")

// MARK: - NodeHandle

extension PathView {
    struct NodeHandle: View, EquatableBy {
        @EnvironmentObject var viewModel: PathViewModel

        let pathId: UUID
        let nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        var body: some View { subtracer.range("NodeHandle \(nodeId)") { build {
            WithSelector(selector, .init(pathId: pathId, nodeId: nodeId)) {
                handle
            }
        }}}

        // MARK: private

        private struct Props: Equatable { let pathId: UUID, nodeId: UUID }
        private class Selector: StoreSelector<Props> {
            override var configs: Configs { .init(syncUpdate: true) }

            @Tracked({ props in global.path.path(id: props.pathId)?.node(id: props.nodeId)?.position.applying(global.viewport.toView) }) var position
            @Tracked({ props in global.pathProperty.property(id: props.pathId)?.nodeType(id: props.nodeId) }) var nodeType
            @Tracked({ props in global.activeItem.pathFocusedPart?.nodeId == props.nodeId }) var focused
        }

        @StateObject private var selector = Selector()

        private static let circleSize: Scalar = 12
        private static let rectSize: Scalar = circleSize / 2 * 1.7725 // sqrt of pi
        private static let touchablePadding: Scalar = 20

        @State private var menuSize: CGSize = .zero
        @State private var viewSize = global.viewport.store.viewSize
        @State private var nodeGestureContext = PathViewModel.NodeGestureContext()

        @ViewBuilder private var handle: some View {
            if let position = selector.position {
                nodeShape
                    .padding(Self.touchablePadding)
                    .invisibleSoildOverlay()
                    .position(position)
                    .multipleGesture(viewModel.nodeGesture(nodeId: nodeId, context: nodeGestureContext))
            }
        }

        @ViewBuilder private var nodeShape: some View {
            if selector.nodeType == .corner {
                Rectangle()
                    .stroke(.blue, style: StrokeStyle(lineWidth: 1))
                    .fill(.blue.opacity(0.5))
                    .if(selector.focused) { $0.overlay {
                        Rectangle()
                            .fill(.blue)
                            .scaleEffect(0.5)
                            .allowsHitTesting(false)
                    }}
                    .frame(width: Self.rectSize, height: Self.rectSize)
            } else {
                Circle()
                    .stroke(.blue, style: StrokeStyle(lineWidth: selector.nodeType == .mirrored ? 2 : 1))
                    .fill(.blue.opacity(0.5))
                    .if(selector.focused) { $0.overlay {
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
