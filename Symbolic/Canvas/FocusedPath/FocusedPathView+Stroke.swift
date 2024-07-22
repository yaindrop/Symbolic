import SwiftUI

private class GestureContext {
    var segmentId: UUID?
    var longPressParamT: Scalar?
    var longPressSplitNodeId: UUID?
}

// MARK: - global actions

private extension GlobalStores {
    func segmentGesture(context: GestureContext) -> MultipleGesture {
        func split(_ v: DragGesture.Value) {
            guard let segmentId = context.segmentId,
                  let segment = activeItem.focusedPath?.segment(fromId: segmentId) else { return }
            let location = v.location.applying(viewport.toWorld)
            let paramT = segment.paramT(closestTo: location).t
            context.longPressParamT = paramT
            let id = UUID()
            context.longPressSplitNodeId = id
            focusedPath.setFocus(node: id)
        }
        func moveSplitNode(paramT: Scalar, newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            guard let segmentId = context.segmentId else { return }
            documentUpdater.updateInView(focusedPath: .splitSegment(.init(fromNodeId: segmentId, paramT: paramT, newNodeId: newNodeId, offset: offset)), pending: pending)
            if !pending {
                context.longPressParamT = nil
            }
        }
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId {
                moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: v.offset, pending: pending)
            } else if let pathId = activeItem.focusedPath?.id {
                documentUpdater.updateInView(path: .move(.init(pathIds: [pathId], offset: v.offset)), pending: pending)
            }
        }
        func updateLongPress(pending: Bool = false) {
            guard let paramT = context.longPressParamT,
                  let newNodeId = context.longPressSplitNodeId else { return }
            moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: .zero, pending: pending)
        }

        return .init(
            configs: .init(durationThreshold: 0.2),
            onPress: { info in
                let location = info.location.applying(viewport.toWorld)
                guard let segmentId = activeItem.focusedPath?.segmentId(closestTo: location) else { return }
                context.segmentId = segmentId
                canvasAction.start(continuous: .movePath)
                canvasAction.start(triggering: .splitPathSegment)
            },
            onPressEnd: { _, cancelled in
                context.segmentId = nil
                canvasAction.end(triggering: .splitPathSegment)
                canvasAction.end(continuous: .splitAndMovePathNode)
                canvasAction.end(continuous: .movePath)
                if cancelled { documentUpdater.cancel() }

            },
            onTap: { _ in
                guard let segmentId = context.segmentId else { return }
                focusedPath.onTap(segment: segmentId)
            },
            onLongPress: {
                split($0)
                updateLongPress(pending: true)
                canvasAction.end(continuous: .movePath)
                canvasAction.end(triggering: .splitPathSegment)
                canvasAction.start(continuous: .splitAndMovePathNode)
            },
            onLongPressEnd: { _ in updateLongPress() },
            onDrag: {
                updateDrag($0, pending: true)
                canvasAction.end(triggering: .splitPathSegment)
            },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - Stroke

extension FocusedPathView {
    struct Stroke: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ global.activeItem.focusedPath }) var path
        }

        @SelectorWrapper var selector

        @State private var gestureContext = GestureContext()

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.Stroke {
    @ViewBuilder var content: some View {
        AnimatableReader(selector.viewport) {
            outline(viewport: $0)
            touchable(viewport: $0)
        }
    }

    @ViewBuilder func outline(viewport: SizedViewportInfo) -> some View {
        SUPath { p in selector.path?.append(to: &p) }
            .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            .transformEffect(viewport.worldToView)
            .allowsHitTesting(false)
    }

    @ViewBuilder func touchable(viewport: SizedViewportInfo) -> some View {
        SUPath { p in selector.path?.append(to: &p) }
            .transform(viewport.worldToView)
            .stroke(.yellow.opacity(0.05), style: StrokeStyle(lineWidth: 24, lineCap: .round))
            .multipleGesture(global.segmentGesture(context: gestureContext))
    }
}
