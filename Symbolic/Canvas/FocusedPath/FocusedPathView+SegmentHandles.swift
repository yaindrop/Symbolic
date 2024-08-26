import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var gesture: MultipleGesture {
        func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            guard let fromId = focusedPath.focusedSegmentId,
                  let toId = activeItem.focusedPath?.nodeId(after: fromId) else { return }
            let offset = v.offset.applying(viewport.viewToWorld)
            documentUpdater.update(focusedPath: .moveNodes(.init(nodeIds: [fromId, toId], offset: offset)), pending: pending)
        }
        return .init(
            onPress: { _ in canvasAction.start(continuous: .movePathSegment) },
            onPressEnd: { _, cancelled in
                canvasAction.end(continuous: .movePathSegment)
                if cancelled { documentUpdater.cancel() }
            },

            onTap: { _ in
                guard let focusedSegmentId = focusedPath.focusedSegmentId else { return }
                focusedPath.onTap(segment: focusedSegmentId)
            },
            onDrag: { updateDrag($0, pending: true) },
            onDragEnd: { updateDrag($0) }
        )
    }
}

// MARK: - SegmentHandles

extension FocusedPathView {
    struct SegmentHandles: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            @Selected(configs: .init(syncNotify: true), { global.viewport.sizedInfo }) var viewport
            @Selected(configs: .init(syncNotify: true), { global.activeItem.focusedPath }) var path
            @Selected({ global.focusedPath.focusedSegmentId }) var focusedSegmentId
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.SegmentHandles {
    var content: some View {
        AnimatableReader(selector.viewport) {
            let transform = selector.symbolToWorld.concatenating($0.worldToView)
            shape(transform: transform)
            touchable(transform: transform)
        }
    }

    var color: Color { .cyan }
    var lineWidth: Scalar { 1 }
    var circleSize: Scalar { 12 }
    var touchableSize: Scalar { 40 }

    @ViewBuilder func shape(transform: CGAffineTransform) -> some View {
        let path = selector.path,
            focusedSegmentId = selector.focusedSegmentId
        if let path, let focusedSegmentId, let segment = path.segment(fromId: focusedSegmentId) {
            let tessellated = segment.tessellated(),
                centerT = tessellated.approxPathParamT(lineParamT: 0.5).t,
                center = segment.position(paramT: centerT).applying(transform),
                fromT = tessellated.approxPathParamT(lineParamT: 0.1).t,
                toT = tessellated.approxPathParamT(lineParamT: 0.9).t,
                subsegment = segment.subsegment(fromT: fromT, toT: toT).applying(transform)
            SUPath { p in appendCircle(to: &p, at: center) }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth))
                .allowsHitTesting(false)
            SUPath { p in subsegment.append(to: &p) }
                .strokedPath(StrokeStyle(lineWidth: 2, lineCap: .round))
                .subtracting(SUPath { p in appendCircle(to: &p, at: center) })
                .fill(color)
                .allowsHitTesting(false)
        }
    }

    func appendCircle(to path: inout SUPath, at point: Point2) {
        path.addEllipse(in: .init(center: point, size: .init(squared: circleSize)))
    }

    @ViewBuilder func touchable(transform: CGAffineTransform) -> some View {
        let path = selector.path,
            focusedSegmentId = selector.focusedSegmentId
        if let path, let focusedSegmentId, let segment = path.segment(fromId: focusedSegmentId) {
            let tessellated = segment.tessellated(),
                centerT = tessellated.approxPathParamT(lineParamT: 0.5).t,
                center = segment.position(paramT: centerT).applying(transform)
            SUPath { p in
                p.addRect(.init(center: center, size: .init(squared: touchableSize)))
            }
            .fill(debugFocusedPath ? .red.opacity(0.1) : .clear)
            .multipleGesture(global.gesture)
        }
    }
}
