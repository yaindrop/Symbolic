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
                VStack(spacing: 0) {
                    ForEach(path.nodes) { node in
                        NodePanel(pathId: path.id, nodeId: node.id)
                        if node.id != path.nodes.last?.id {
                            Divider()
                        }
                    }
                }
                .background(.ultraThickMaterial)
                .clipRounded(radius: 12)
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
//                NodePanel(path: path, property: property, focusedPart: focusedPart, index: index, node: node)
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
