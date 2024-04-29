import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - Components

    struct Components: View {
        let activePath: Path

        @ViewBuilder var body: some View {
            VStack(spacing: 4) {
                sectionTitle("Components")
                VStack(spacing: 12) {
                    ForEach(activePath.segments) { segment in
                        NodeEdgeGroup(segment: segment)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }

        // MARK: private

        @EnvironmentObject private var pathStore: PathStore
        @EnvironmentObject private var activePathModel: ActivePathModel

        @ViewBuilder private func sectionTitle(_ title: String) -> some View {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryLabel)
                    .padding(.leading, 12)
                Spacer()
            }
        }
    }

    // MARK: - NodeEdgeGroup

    fileprivate struct NodeEdgeGroup: View {
        let segment: PathSegment

        var body: some View {
            Group {
                NodePanel(index: segment.index, node: segment.node)
                EdgePanel(fromNodeId: segment.id, edge: segment.edge)
            }
            .scaleEffect(scale)
            .onChange(of: focused) { animateOnFocused() }
        }

        @EnvironmentObject private var activePathModel: ActivePathModel
        @State private var scale: Double = 1

        private var focused: Bool { activePathModel.focusedPart?.id == segment.id }

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
