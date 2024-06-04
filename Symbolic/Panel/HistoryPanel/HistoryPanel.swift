import Foundation
import SwiftUI

private extension DocumentEvent {
    var name: String {
        switch action {
        case let .pathAction(pathAction):
            switch pathAction {
            case let .load(action): "Load path \(action.path.id.uuidString.prefix(4))"
            case let .create(action): "Create path \(action.path.id.uuidString.prefix(4))"
            case let .move(action): "Move \(action.pathIds.map { $0.uuidString.prefix(4) }) by \(action.offset)"
            case let .delete(action): "Delete \(action.pathIds.map { $0.uuidString.prefix(4) })"
            case let .single(single):
                switch single.kind {
                case let .deleteNode(action): "In path \(single.pathId.uuidString.prefix(4)) delete node \(action.nodeId.uuidString.prefix(4))"
                case let .setNodePosition(action): "In path \(single.pathId.uuidString.prefix(4)) set node \(action.nodeId.uuidString.prefix(4)) to \(action.position)"
                case let .setEdge(action): "In path \(single.pathId.uuidString.prefix(4)) set edge from \(action.fromNodeId.uuidString.prefix(4))"

                case let .addEndingNode(action): "In path \(single.pathId.uuidString.prefix(4)) add ending node from \(action.endingNodeId.uuidString.prefix(4)) to \(action.newNodeId.uuidString.prefix(4)) with \(action.offset)"
                case let .splitSegment(action): "In path \(single.pathId.uuidString.prefix(4)) split segment from \(action.fromNodeId.uuidString.prefix(4)) at \(action.paramT) to \(action.newNodeId.uuidString.prefix(4)) with \(action.offset)"

                case let .move(action): "Move path \(single.pathId.uuidString.prefix(4)) by \(action.offset)"
                case let .moveNode(action): "In path \(single.pathId.uuidString.prefix(4)) move node \(action.nodeId.uuidString.prefix(4)) by \(action.offset)"
                case let .moveEdge(action): "In path \(single.pathId.uuidString.prefix(4)) move edge from \(action.fromNodeId.uuidString.prefix(4)) by \(action.offset)"
                case let .moveEdgeControl(action): "In path \(single.pathId.uuidString.prefix(4)) move edge control from \(action.fromNodeId.uuidString.prefix(4)) by \(action.offset0) and \(action.offset1)"
                }
            case .merge: "Merge paths"
            case let .breakAtNode(action): "Break path \(action.pathId.uuidString.prefix(4)) at node \(action.nodeId.uuidString.prefix(4))"
            case let .breakAtEdge(action): "Break path \(action.pathId.uuidString.prefix(4)) at edge from \(action.fromNodeId.uuidString.prefix(4))"
            }
        case let .itemAction(action):
            switch action {
            case let .group(action):
                "Group of \(action.group.members.map { $0.uuidString.prefix(4) }) as \(action.group.id.uuidString.prefix(4))"
            case let .ungroup(action):
                "Ungroup \(action.groupIds.map { $0.uuidString.prefix(4) })"
            case let .reorder(action):
                "Reorder \(action.inGroupId.map { $0.uuidString.prefix(4) } ?? "root")"
            }
        }
    }
}

// MARK: - HistoryPanel

struct HistoryPanel: View {
    let panelId: UUID

    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @Selected private var document = global.document.activeDocument

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
                ForEach(document.events) { e in
                    Text("\(e.name)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
