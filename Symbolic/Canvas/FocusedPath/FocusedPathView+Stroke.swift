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
            let location = v.location.applying(activeSymbol.viewToSymbol)
            let paramT = segment.paramT(closestTo: location).t
            context.longPressParamT = paramT
            let id = UUID()
            context.longPressSplitNodeId = id
            focusedPath.setFocus(node: id)
        }
        func moveSplitNode(paramT: Scalar, newNodeId: UUID, offset: Vector2, pending: Bool = false) {
            guard let segmentId = context.segmentId else { return }
            documentUpdater.update(focusedPath: .splitSegment(.init(fromNodeId: segmentId, paramT: paramT, newNodeId: newNodeId, offset: offset)), pending: pending)
            if !pending {
                context.longPressParamT = nil
            }
        }
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            let offset = v.offset.applying(activeSymbol.viewToSymbol)
            if let paramT = context.longPressParamT, let newNodeId = context.longPressSplitNodeId {
                moveSplitNode(paramT: paramT, newNodeId: newNodeId, offset: offset, pending: pending)
            } else if let pathId = activeItem.focusedPathId {
                documentUpdater.update(path: .move(.init(pathIds: [pathId], offset: v.offset)), pending: pending)
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
                let location = info.location.applying(activeSymbol.viewToSymbol)
                guard let segmentId = activeItem.focusedPath?.segmentId(closestTo: location) else { return }
                context.segmentId = segmentId
                canvasAction.start(continuous: .movePath)
                canvasAction.start(triggering: .pathSplitSegment)
            },
            onPressEnd: { _, cancelled in
                context.segmentId = nil
                canvasAction.end(triggering: .pathSplitSegment)
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
                canvasAction.end(triggering: .pathSplitSegment)
                canvasAction.start(continuous: .splitAndMovePathNode)
            },
            onLongPressEnd: { _ in updateLongPress() },
            onDrag: {
                updateDrag($0, pending: true)
                canvasAction.end(triggering: .pathSplitSegment)
            },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - Stroke

extension FocusedPathView {
    struct Stroke: View, TracedView, SelectorHolder {
        @Environment(\.transformToView) var transformToView

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
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
//            outline
        touchable
    }

    @ViewBuilder var outline: some View {
        SUPath { p in selector.path?.append(to: &p) }
            .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            .transformEffect(transformToView)
            .allowsHitTesting(false)
    }

    @ViewBuilder var touchable: some View {
        SUPath { p in selector.path?.append(to: &p) }
            .transform(transformToView)
            .stroke(debugFocusedPath ? .yellow.opacity(0.05) : .invisibleSolid, style: StrokeStyle(lineWidth: 24, lineCap: .round))
            .multipleGesture(global.segmentGesture(context: gestureContext))
    }
}
