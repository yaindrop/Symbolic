import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PathView")

// MARK: - NodeHandle

extension PathView {
    struct NodeHandle: View, EquatableBy, ReflectiveSelectorHolder {
        class Selector: SelectorBase {
            override var configs: Configs { .init(syncUpdate: true) }

            @Selected({ global.path.path(id: $0.pathId)?.node(id: $0.nodeId)?.position.applying(global.viewport.toView) }) var position
            @Selected({ global.pathProperty.property(id: $0.pathId)?.nodeType(id: $0.nodeId) }) var nodeType
            @Selected({ global.activeItem.pathFocusedPart?.nodeId == $0.nodeId }) var focused
        }

        @StateObject var selector = Selector()

        @EnvironmentObject var viewModel: PathViewModel

        let pathId: UUID
        let nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        var body: some View { subtracer.range("NodeHandle \(nodeId)") { build {
            setupSelector {
                handle
            }
        }}}

        // MARK: private

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
