import Foundation
import SwiftUI

extension ActivePathPanel {
    struct Components: View {
        @ViewBuilder var body: some View {
            if let activePath = activePathModel.pendingActivePath {
                ScrollViewReader { proxy in
                    ScrollView {
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
                        .scrollOffsetReader(model: scrollOffset)
                    }
                    .onChange(of: activePathModel.focusedPart) {
                        guard let id = activePathModel.focusedPart?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
                    }
                }
                .scrollOffsetProvider(model: scrollOffset)
                .frame(maxHeight: 400)
                .fixedSize(horizontal: false, vertical: true)
                .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            }
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

        @StateObject private var scrollOffset = ScrollOffsetModel()
    }

    // MARK: - Component rows

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
