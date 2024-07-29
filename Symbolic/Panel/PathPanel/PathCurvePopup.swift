import SwiftUI

// MARK: - CurvePopup

struct PathCurvePopup: View, TracedView, ComputedSelectorHolder {
    let pathId: UUID, nodeId: UUID, isOut: Bool

    struct SelectorProps: Equatable { let pathId: UUID, nodeId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.path.get(id: $0.pathId) }) var path
        @Selected({ global.pathProperty.get(id: $0.pathId) }) var pathProperty
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(pathId: pathId, nodeId: nodeId)) {
            content
        }
    } }
}

// MARK: private

private extension PathCurvePopup {
    var node: PathNode? { selector.path?.node(id: nodeId) }

    var segmentType: PathSegmentType? {
        if isOut {
            selector.pathProperty?.segmentType(id: nodeId)
        } else {
            selector.path?.nodeId(before: nodeId).map { selector.pathProperty?.segmentType(id: $0) }
        }
    }

    var fromNodeId: UUID? { isOut ? nodeId : selector.path?.nodeId(before: nodeId) }

    var toNodeId: UUID? { isOut ? selector.path?.nodeId(after: nodeId) : nodeId }

    @ViewBuilder var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Curve \(isOut ? "Out" : "In")")
                    .font(.callout.bold())
                Spacer()
            }
            .padding(12)
            .background(.ultraThickMaterial.shadow(.drop(color: .label.opacity(0.1), radius: 6)))
            VStack(spacing: 0) {
                PanelRow(name: "Control") {
                    let value = isOut ? node?.controlOut : node?.controlIn
                    VectorPicker(value: value ?? .zero) { update(value: $0, pending: true) } onDone: { update(value: $0) }
                        .background(.ultraThickMaterial)
                        .clipRounded(radius: 6)
                }
                Divider()
                PanelRow(name: "Segment") {
                    segmentIcon
                }
                Divider()
                PanelRow(name: "Type") {
                    CasePicker<PathSegmentType>(cases: [.line, .cubic, .quadratic], value: segmentType ?? .auto) { $0.name } onValue: { update(segmentType: $0) }
                        .background(.ultraThickMaterial)
                        .clipRounded(radius: 6)
                        .animation(nil, value: segmentType)
                }
                Divider()
                PanelRow {
                    Button("Split", systemImage: "square.split.diagonal") {}
                        .font(.footnote)
                    Spacer()
                    Button("Delete", systemImage: "trash", role: .destructive) {}
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 12)
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
        .frame(maxWidth: 240)
    }

    var segmentIcon: some View {
        HStack(spacing: 0) {
            nodeIcon(nodeId: fromNodeId)
                .scaleEffect(isOut ? 1 : 0.9)
                .opacity(isOut ? 1 : 0.5)
            Image(systemName: "arrow.forward")
                .font(.caption)
                .padding(6)
            nodeIcon(nodeId: toNodeId)
                .scaleEffect(isOut ? 0.9 : 1)
                .opacity(isOut ? 0.5 : 1)
        }
    }

    func nodeIcon(nodeId: UUID?) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "smallcircle.filled.circle")
                .font(.callout)
            Spacer(minLength: 0)
            Text(nodeId?.shortDescription ?? "nil")
                .font(.system(size: 10).monospaced())
        }
        .frame(width: 32, height: 32)
    }

    func update(value: Vector2? = nil, pending: Bool = false) {
        if var node {
            if isOut {
                value.map { node.controlOut = $0 }
            } else {
                value.map { node.controlIn = $0 }
            }
            global.documentUpdater.update(focusedPath: .setNode(.init(nodeId: nodeId, node: node)), pending: pending)
        }
    }

    func update(segmentType: PathSegmentType) {
        if let pathId = selector.path?.id, let fromNodeId {
            let segmentType = segmentType == self.segmentType ? nil : segmentType
            global.documentUpdater.update(pathProperty: .update(.init(pathId: pathId, kind: .setSegmentType(.init(fromNodeIds: [fromNodeId], segmentType: segmentType)))))
        }
    }
}
