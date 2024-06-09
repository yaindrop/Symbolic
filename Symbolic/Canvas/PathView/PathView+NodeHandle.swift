import SwiftUI

// MARK: - NodeHandle

extension PathView {
    struct NodeHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @EnvironmentObject var viewModel: PathViewModel

        let pathId: UUID
        let nodeId: UUID

        var equatableBy: some Equatable { pathId; nodeId }

        struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.path.path(id: $0.pathId)?.node(id: $0.nodeId)?.position.applying(global.viewport.toView) }) var position
            @Selected({ global.pathProperty.property(id: $0.pathId)?.nodeType(id: $0.nodeId) }) var nodeType
            @Selected({ global.focusedPath.activeNodeIds.contains($0.nodeId) }) var active
            @Selected(animation: .fast, { global.focusedPath.selectingNodes }) var selectingNodes
        }

        @SelectorWrapper var selector

        @State private var nodeGestureContext = PathViewModel.NodeGestureContext()

        var body: some View { trace {
            setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
                handle
            }
        } }
    }
}

// MARK: private

extension PathView.NodeHandle {
    var circleSize: Scalar { 12 }
    var rectSize: Scalar { circleSize / 2 * 1.7725 } // sqrt of pi
    var touchablePadding: Scalar { 20 }

    @ViewBuilder var handle: some View {
        if let position = selector.position {
            nodeShape
                .padding(touchablePadding)
                .invisibleSoildOverlay()
                .position(position)
                .multipleGesture(viewModel.nodeGesture(nodeId: nodeId, context: nodeGestureContext))
        }
    }

    @ViewBuilder var nodeShape: some View {
        if selector.nodeType == .corner {
            Rectangle()
                .stroke(.blue, style: StrokeStyle(lineWidth: 1))
                .fill(.blue.opacity(0.3))
                .if(!selector.selectingNodes && selector.active) { $0.overlay {
                    Rectangle()
                        .fill(.blue)
                        .scaleEffect(0.5)
                        .allowsHitTesting(false)
                }}
                .frame(size: .init(squared: rectSize * (selector.selectingNodes ? 1.5 : 1)))
        } else {
            Circle()
                .stroke(.blue, style: StrokeStyle(lineWidth: selector.nodeType == .mirrored ? 2 : 1))
                .fill(.blue.opacity(0.3))
                .if(!selector.selectingNodes && selector.active) { $0.overlay {
                    Circle()
                        .fill(.blue)
                        .scaleEffect(0.5)
                        .allowsHitTesting(false)
                }}
                .frame(size: .init(squared: circleSize * (selector.selectingNodes ? 1.5 : 1)))
        }
    }
}
