import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - Components

    struct Components: View {
        let activePath: Path

        @ViewBuilder var body: some View { tracer.range("ActivePathPanel Components body") {
            VStack(spacing: 4) {
                PanelSectionTitle(name: "Components")
                VStack(spacing: 12) {
                    ForEach(activePath.pairs.values, id: \.node.id) { p in
                        let i = activePath.nodeIndex(id: p.node.id) ?? 0
                        NodeEdgeGroup(index: i, node: p.node, edge: p.edge, hasNext: activePath.isClosed || i + 1 < activePath.count)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }}
    }

    // MARK: - NodeEdgeGroup

    fileprivate struct NodeEdgeGroup: View {
        let index: Int
        let node: PathNode
        let edge: PathEdge
        let hasNext: Bool

        @Selected var focused: Bool

        var body: some View {
            Group {
                NodePanel(index: index, node: node)
                if hasNext {
                    EdgePanel(fromNodeId: node.id, edge: edge)
                }
            }
            .scaleEffect(scale)
            .onChange(of: focused) { animateOnFocused() }
        }

        init(index: Int, node: PathNode, edge: PathEdge, hasNext: Bool) {
            self.index = index
            self.node = node
            self.edge = edge
            self.hasNext = hasNext
            _focused = .init { store.activePathModel.focusedPart?.id == node.id }
        }

        @State private var scale: Double = 1

        func animateOnFocused() {
            if focused {
                withAnimation(.easeInOut(duration: 0.2).delay(0.2)) {
                    scale = 1.1
                } completion: {
                    withAnimation(.easeInOut(duration: 0.2)) { scale = 1 }
                }
            }
        }
    }
}
