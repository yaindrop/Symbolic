import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - Components

    struct Components: View {
        let activePath: Path

        @ViewBuilder var body: some View {
            VStack(spacing: 4) {
                PanelSectionTitle(name: "Components")
                VStack(spacing: 12) {
                    ForEach(activePath.pairs, id: \.node.id) { p in
                        let i = activePath.nodeIdToIndex[p.node.id] ?? 0
                        NodeEdgeGroup(index: i, node: p.node, edge: p.edge, hasNext: activePath.isClosed || i + 1 < activePath.count)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }

        // MARK: private

        @EnvironmentObject private var pathStore: PathStore
        @EnvironmentObject private var activePathModel: ActivePathModel
    }

    // MARK: - NodeEdgeGroup

    fileprivate struct NodeEdgeGroup: View {
        let index: Int
        let node: PathNode
        let edge: PathEdge
        let hasNext: Bool

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

        @EnvironmentObject private var activePathModel: ActivePathModel
        @State private var scale: Double = 1

        private var focused: Bool { activePathModel.focusedPart?.id == node.id }

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
