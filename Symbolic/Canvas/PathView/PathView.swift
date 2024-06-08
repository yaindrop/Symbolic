import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PathView")

// MARK: - PathViewModel

class PathViewModel: ObservableObject {
    class NodeGestureContext {
        var longPressAddedNodeId: UUID?
    }

    func nodeGesture(nodeId _: UUID, context _: NodeGestureContext) -> MultipleGesture { .init() }

    class EdgeGestureContext {
        var longPressParamT: Scalar?
        var longPressSplitNodeId: UUID?
    }

    func edgeGesture(fromId _: UUID, segment _: PathSegment, context _: EdgeGestureContext) -> MultipleGesture { .init() }
    func focusedEdgeGesture(fromId _: UUID) -> MultipleGesture { .init() }

    func bezierGesture(fromId _: UUID, isControl0 _: Bool) -> MultipleGesture { .init() }
}

// MARK: - PathView

struct PathView: View {
    let path: Path
    let property: PathProperty
    let focusedPart: PathFocusedPart?

    var body: some View { subtracer.range("body") {
        ZStack {
            Stroke(path: path)
            handles(path: path)
        }

    }}

    // MARK: private

    @ViewBuilder private func handles(path: Path) -> some View {
        let nodes = path.nodes
        let segmentFromIds = nodes.compactMap { n in path.segment(from: n.id).map { _ in n.id } }
        ForEach(segmentFromIds) { EdgeHandle(pathId: path.id, fromNodeId: $0) }
        ForEach(nodes) { NodeHandle(pathId: path.id, nodeId: $0.id) }
        ForEach(segmentFromIds) { FocusedEdgeHandle(pathId: path.id, fromNodeId: $0) }
        ForEach(segmentFromIds) { BezierHandle(pathId: path.id, fromNodeId: $0) }
    }
}

// MARK: - Stroke

extension PathView {
    struct Stroke: View, SelectorHolder {
        class Selector: SelectorBase {
            override var configs: Configs { .init(name: "Stroke", syncUpdate: true) }

            @Selected({ global.viewport.toView }) var toView
        }

        @StateObject var selector = Selector()

        let path: Path

        var body: some View { subtracer.range("Stroke") {
            setupSelector {
                content
            }
        }}

        private var content: some View {
            SUPath { path.append(to: &$0) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .id(path.id)
                .transformEffect(selector.toView)
        }
    }
}
