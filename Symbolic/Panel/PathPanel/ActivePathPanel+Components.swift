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
                        NodeEdgeGroup(path: activePath, index: i, node: p.node, edge: p.edge)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }}
    }

    // MARK: - NodeEdgeGroup

    fileprivate struct NodeEdgeGroup: View {
        let path: Path
        let index: Int
        let node: PathNode
        let edge: PathEdge

        var body: some View {
            Group {
                NodePanel(path: path, index: index, node: node)
                if !path.isLastEndingNode(id: node.id) {
                    EdgePanel(fromNodeId: node.id, edge: edge)
                }
            }
            .scaleEffect(scale)
            .onChange(of: focused) { animateOnFocused() }
        }

        init(path: Path, index: Int, node: PathNode, edge: PathEdge) {
            self.path = path
            self.index = index
            self.node = node
            self.edge = edge
            _focused = .init { global.activeItem.pathFocusedPart?.id == node.id }
        }

        @Selected private var focused: Bool

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
