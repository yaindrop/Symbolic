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
                "Load path \(action.paths.map { $0.id.shortDescription }.joined(separator: ", "))"
            case let .create(action):
                "Create path \(action.path.id.shortDescription)"
            case let .move(action):
                "Move path \(action.pathIds.map { $0.shortDescription }.joined(separator: ", ")) by \(action.offset.shortDescription)"
            case let .delete(action):
                "Delete path \(action.pathIds.map { $0.shortDescription }.joined(separator: ", "))"

            case let .update(update):
                switch update.kind {
                case let .deleteNodes(action):
                    "In path \(update.pathId.shortDescription) delete node \(action.nodeIds.map { $0.shortDescription })"
                case let .updateNode(action):
                    "In path \(update.pathId.shortDescription) set node \(action.nodeId.shortDescription) to \(action.node)"

                case let .addEndingNode(action):
                    "In path \(update.pathId.shortDescription) add ending node from \(action.endingNodeId.shortDescription) to \(action.newNodeId.shortDescription) with \(action.offset.shortDescription)"
                case let .splitSegment(action):
                    "In path \(update.pathId.shortDescription) split segment from \(action.fromNodeId.shortDescription) at \(action.paramT) to \(action.newNodeId.shortDescription) with \(action.offset.shortDescription)"

                case let .moveNodes(action):
                    "In path \(update.pathId.shortDescription) move node \(action.nodeIds.map { $0.id.shortDescription }.joined(separator: ", ")) by \(action.offset.shortDescription)"
                case let .moveNodeControl(action):
                    "In path \(update.pathId.shortDescription) move node control from \(action.nodeId.shortDescription) by \(action.offset.shortDescription) of \(action.controlType)"
                }

            case let .merge(action):
                "Merge path \(action.pathId.shortDescription) node \(action.endingNodeId.shortDescription) with path \(action.mergedPathId.shortDescription) node \(action.mergedEndingNodeId.shortDescription)"
            case let .breakAtNode(action):
                "Break path \(action.pathId.shortDescription) at node \(action.nodeId.shortDescription)"
            case let .breakAtSegment(action):
                "Break path \(action.pathId.shortDescription) at segment from \(action.fromNodeId.shortDescription)"
            }

        case let .pathProperty(action):
            switch action {
            case let .update(update):
                switch update.kind {
                case let .setName(action):
                    "Set path \(update.pathId.shortDescription) name \(action.name ?? "nil")"
                case let .setNodeType(action):
                    "Set path \(update.pathId.shortDescription) node \(action.nodeIds.map { $0.shortDescription }.joined(separator: ", ")) type \(action.nodeType?.description ?? "nil")"
                case let .setSegmentType(action):
                    "Set path \(update.pathId.shortDescription) segment from \(action.fromNodeIds.map { $0.shortDescription }.joined(separator: ", ")) type \(action.segmentType?.description ?? "nil")"
                }
            }
        }
    }
}

// MARK: - HistoryPanel

struct HistoryPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.document.activeDocument }) var document
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

extension HistoryPanel {
    @ViewBuilder private var content: some View {
        events
    }

    @ViewBuilder private var events: some View {
        PanelSection(name: "Events") {
            ForEach(selector.document.events) {
                EventRow(event: $0)
                if $0 != selector.document.events.last {
                    Divider().padding(.leading, 12)
                }
            }
        }
    }
}

private struct EventRow: View, EquatableBy {
    let event: DocumentEvent

    var equatableBy: some Equatable { event }

    var body: some View {
        HStack {
            Text("\(event.action.readable)")
                .font(.footnote)
            Spacer()
        }
        .padding(12)
    }
}
