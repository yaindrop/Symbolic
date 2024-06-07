import Foundation
import SwiftUI

private extension DocumentAction {
    var readable: String {
        switch self {
        case let .item(action):
            switch action {
            case let .group(action):
                "Group of \(action.group.members.map { $0.shortDescription }.joined(separator: ", ")) as \(action.group.id.shortDescription) in \(action.inGroupId.map { $0.shortDescription } ?? "root")"
            case let .ungroup(action):
                "Ungroup \(action.groupIds.map { $0.shortDescription }.joined(separator: ", "))"
            case let .reorder(action):
                "Reorder \(action.inGroupId.map { $0.shortDescription } ?? "root")"
            }
        case let .path(action):
            switch action {
            case let .load(action):
                "Load path \(action.path.id.shortDescription)"
            case let .create(action):
                "Create path \(action.path.id.shortDescription)"
            case let .delete(action):
                "Delete path \(action.pathIds.map { $0.shortDescription }.joined(separator: ", "))"
            case let .update(update):
                switch update.kind {
                case let .deleteNode(action):
                    "In path \(update.pathId.shortDescription) delete node \(action.nodeId.shortDescription)"
                case let .setNodePosition(action):
                    "In path \(update.pathId.shortDescription) set node \(action.nodeId.shortDescription) to \(action.position.shortDescription)"
                case let .setEdge(action):
                    "In path \(update.pathId.shortDescription) set edge from \(action.fromNodeId.shortDescription)"

                case let .addEndingNode(action):
                    "In path \(update.pathId.shortDescription) add ending node from \(action.endingNodeId.shortDescription) to \(action.newNodeId.shortDescription) with \(action.offset.shortDescription)"
                case let .splitSegment(action):
                    "In path \(update.pathId.shortDescription) split segment from \(action.fromNodeId.shortDescription) at \(action.paramT) to \(action.newNodeId.shortDescription) with \(action.offset.shortDescription)"

                case let .move(action):
                    "Move path \(update.pathId.shortDescription) by \(action.offset.shortDescription)"
                case let .moveNode(action):
                    "In path \(update.pathId.shortDescription) move node \(action.nodeId.shortDescription) by \(action.offset.shortDescription)"
                case let .moveEdge(action):
                    "In path \(update.pathId.shortDescription) move edge from \(action.fromNodeId.shortDescription) by \(action.offset.shortDescription)"
                case let .moveEdgeControl(action):
                    "In path \(update.pathId.shortDescription) move edge control from \(action.fromNodeId.shortDescription) by \(action.offset0.shortDescription) and \(action.offset1.shortDescription)"
                }
            case let .move(action):
                "Move path \(action.pathIds.map { $0.shortDescription }.joined(separator: ", ")) by \(action.offset.shortDescription)"
            case let .merge(action):
                "Merge path \(action.pathId.shortDescription) node \(action.endingNodeId.shortDescription) with path \(action.mergedPathId.shortDescription) node \(action.mergedEndingNodeId.shortDescription)"
            case let .breakAtNode(action):
                "Break path \(action.pathId.shortDescription) at node \(action.nodeId.shortDescription)"
            case let .breakAtEdge(action):
                "Break path \(action.pathId.shortDescription) at edge from \(action.fromNodeId.shortDescription)"
            }
        case let .pathProperty(action):
            switch action {
            case let .update(update):
                switch update.kind {
                case let .setName(action):
                    "Set path \(update.pathId.shortDescription) name \(action.name ?? "nil")"
                case let .setNodeType(action):
                    "Set path \(update.pathId.shortDescription) node \(action.nodeId.shortDescription) type \(action.nodeType?.description ?? "nil")"
                case let .setEdgeType(action):
                    "Set path \(update.pathId.shortDescription) edge from \(action.fromNodeId.shortDescription) type \(action.edgeType?.description ?? "nil")"
                }
            }
        }
    }
}

// MARK: - HistoryPanel

struct HistoryPanel: View {
    let panelId: UUID

    var body: some View {
        WithSelector(selector, .value) {
            panel.frame(width: 320)
        }
    }

    // MARK: private

    private class Selector: StoreSelector<Monostate> {
        @Tracked({ global.document.activeDocument }) var document
    }

    @StateObject private var selector = Selector()

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "History")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .multipleGesture(global.panel.moveGesture(panelId: panelId))
            scrollView
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
    }

    @ViewBuilder private var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { _ in
            content
        }
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 4) {
            PanelSectionTitle(name: "Events")
            VStack(spacing: 12) {
                ForEach(selector.document.events) { e in
                    HStack {
                        Text("\(e.action.readable)")
                            .font(.footnote)
                        Spacer()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipRounded(radius: 12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
