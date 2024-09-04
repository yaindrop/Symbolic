import SwiftUI

private extension DocumentAction {
    var readable: String {
        switch self {
        case let .path(action):
            switch action {
            case let .create(action):
                "Create path \(action.pathId.shortDescription)"
            case let .update(update):
                switch update.kind {
                case let .addEndingNode(action):
                    "In path \(update.pathId.shortDescription) add ending node from \(action.endingNodeId.shortDescription) to \(action.newNodeId.shortDescription) with \(action.offset.shortDescription)"
                case let .splitSegment(action):
                    "In path \(update.pathId.shortDescription) split segment from \(action.fromNodeId.shortDescription) at \(action.paramT) to \(action.newNodeId.shortDescription) with \(action.offset.shortDescription)"
                case let .deleteNodes(action):
                    "In path \(update.pathId.shortDescription) delete node \(action.nodeIds.map { $0.shortDescription })"

                case let .updateNode(action):
                    "In path \(update.pathId.shortDescription) set node \(action.nodeId.shortDescription) to \(action.node)"
                case let .updateSegment(action):
                    "In path \(update.pathId.shortDescription) update segment from \(action.fromNodeId.shortDescription) with \(action.segment)"

                case let .moveNodes(action):
                    "In path \(update.pathId.shortDescription) move node \(action.nodeIds.map { $0.id.shortDescription }.joined(separator: ", ")) by \(action.offset.shortDescription)"
                case let .moveNodeControl(action):
                    "In path \(update.pathId.shortDescription) move node control from \(action.nodeId.shortDescription) by \(action.offset.shortDescription) of \(action.controlType)"

                case let .merge(action):
                    "In path \(update.pathId.shortDescription) merge node \(action.endingNodeId.shortDescription) with path \(action.mergedPathId.shortDescription) node \(action.mergedEndingNodeId.shortDescription)"
                case let .split(action):
                    "In path \(update.pathId.shortDescription) split at node \(action.nodeId.shortDescription) with new node \(action.newNodeId?.shortDescription ?? "nil")"

                case let .setNodeType(action):
                    "Set path \(update.pathId.shortDescription) node \(action.nodeIds.map { $0.shortDescription }.joined(separator: ", ")) type \(action.nodeType?.description ?? "nil")"
                case let .setSegmentType(action):
                    "Set path \(update.pathId.shortDescription) segment from \(action.fromNodeIds.map { $0.shortDescription }.joined(separator: ", ")) type \(action.segmentType?.description ?? "nil")"
                }

            case let .delete(action):
                "Delete path \(action.pathIds.map { $0.shortDescription }.joined(separator: ", "))"
            case let .move(action):
                "Move path \(action.pathIds.map { $0.shortDescription }.joined(separator: ", ")) by \(action.offset.shortDescription)"
            }

        case let .symbol(action):
            switch action {
            case let .create(action):
                "Create symbol \(action.symbolId.shortDescription)"
            case let .resize(action):
                "Resize symbol \(action.symbolId.shortDescription) with align \(action.align) and offset \(action.offset.shortDescription)"
            case let .setGrid(action):
                "Set grid of symbol \(action.symbolId.shortDescription) at index \(action.index) and grid \(action.grid.debugDescription)"

            case let .delete(action):
                "Delete symbol \(action.symbolIds.map { $0.shortDescription }.joined(separator: ", "))"
            case let .move(action):
                "Move symbol \(action.symbolIds.map { $0.shortDescription }.joined(separator: ", ")) by \(action.offset.shortDescription)"
            }

        case let .item(action):
            switch action {
            case let .group(action):
                "Group of \(action.members.map { $0.shortDescription }.joined(separator: ", ")) as \(action.groupId.shortDescription) in \(action.inGroupId.map { $0.shortDescription } ?? "root")"
            case let .ungroup(action):
                "Ungroup \(action.groupIds.map { $0.shortDescription }.joined(separator: ", "))"
            case let .reorder(action):
                "Reorder \(action.itemId.shortDescription) to \(action.isAfter ? "after" : "before") \(action.toItemId.shortDescription)"

            case let .setName(action):
                "Set item \(action.itemId.shortDescription) name \(action.name ?? "nil")"
            case let .setLocked(action):
                "Set item \(action.itemIds.map { $0.shortDescription }.joined(separator: ", ")) locked \(action.locked)"
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
            Text("\(event.action?.readable)")
                .font(.footnote)
            Spacer()
        }
        .padding(12)
    }
}
