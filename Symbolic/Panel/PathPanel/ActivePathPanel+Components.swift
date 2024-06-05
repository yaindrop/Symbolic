import Foundation
import SwiftUI

// MARK: - Components

extension ActivePathPanel {
    struct Components: View {
        let path: Path
        let property: PathProperty
        let focusedPart: PathFocusedPart?

        @ViewBuilder var body: some View { tracer.range("ActivePathPanel Components body") {
            VStack(spacing: 4) {
                PanelSectionTitle(name: "Components")
                VStack(spacing: 12) {
                    ForEach(path.pairs.values, id: \.node.id) { p in
                        let i = path.nodeIndex(id: p.node.id) ?? 0
                        NodeEdgeGroup(path: path, property: property, focusedPart: focusedPart, index: i, node: p.node, edge: p.edge)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }}
    }
}

// MARK: - NodeEdgeGroup

private extension ActivePathPanel {
    struct NodeEdgeGroup: View {
        let path: Path
        let property: PathProperty
        let focusedPart: PathFocusedPart?
        let index: Int
        let node: PathNode
        let edge: PathEdge

        var body: some View {
            Group {
                NodePanel(path: path, property: property, focusedPart: focusedPart, index: index, node: node)
                if !path.isLastEndingNode(id: node.id) {
                    EdgePanel(path: path, property: property, focusedPart: focusedPart, fromNodeId: node.id)
                }
            }
            .scaleEffect(scale)
            .onChange(of: focused) { animateOnFocused() }
        }

        private var focused: Bool { focusedPart?.id == node.id }

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
