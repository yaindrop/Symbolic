import Foundation
import SwiftUI

// MARK: - ActivePathEdgeHandle

struct ActivePathEdgeHandle: View {
    let fromId: UUID
    let segment: PathSegment

    var body: some View {
        outline
//        if let longPressPosition {
//            circle(at: p, color: .teal)
//        }
    }

    @State private var longPressParamT: Scalar?
    @State private var longPressSplitNodeId: UUID?

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    private var focused: Bool { activePathModel.focusedEdgeId == fromId }
    private func toggleFocus() {
        withAnimation {
            activePathModel.focusedPart = focused ? nil : .edge(fromId)
        }
    }

    @ViewBuilder private var outline: some View {
        SUPath { p in segment.append(to: &p) }
            .strokedPath(StrokeStyle(lineWidth: 24, lineCap: .round))
            .fill(Color.invisibleSolid)
            .modifier(gesture)
    }

    private var gesture: MultipleGestureModifier<PathSegment> {
        func split(at p: Point2, pending: Bool = false) {
            guard let longPressParamT, let longPressSplitNodeId else { return }
            updater.updateActivePath(splitSegment: fromId, paramT: longPressParamT, newNodeId: longPressSplitNodeId, positionInView: p, pending: pending)
            if !pending {
                self.longPressParamT = nil
            }
        }
        return MultipleGestureModifier(segment,
                                       onTap: { _, _ in toggleFocus() },
                                       onLongPress: { v, s in
                                           withAnimation {
                                               let t = s.paramT(closestTo: v.location).t
                                               longPressParamT = t
                                               let id = UUID()
                                               longPressSplitNodeId = id
                                               split(at: s.position(paramT: t), pending: true)
                                               activePathModel.focusedPart = .node(id)
                                           }
                                       },
                                       onLongPressEnd: { _, s in
                                           guard let longPressParamT else { return }
                                           split(at: s.position(paramT: longPressParamT))
                                       },
                                       onDrag: { v, _ in split(at: v.location, pending: true) },
                                       onDragEnd: { v, _ in split(at: v.location) })
    }

    private static let circleSize: Scalar = 16
    private static let lineWidth: Scalar = 2

    @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color)
            .frame(width: Self.circleSize, height: Self.circleSize)
            .invisibleSoildOverlay()
            .position(point)
    }
}

// MARK: - ActivePathFocusedEdgeHandle

struct ActivePathFocusedEdgeHandle: View {
    let fromId: UUID
    let segment: PathSegment

    var body: some View {
        if let circlePosition, focused {
            circle(at: circlePosition, color: .cyan)
        }
    }

    private static let lineWidth: Scalar = 2
    private static let circleSize: Scalar = 16
    private static let touchablePadding: Scalar = 16

    @EnvironmentObject private var activePathModel: ActivePathModel
    @EnvironmentObject private var updater: PathUpdater

    private var focused: Bool { activePathModel.focusedEdgeId == fromId }

    private var circlePosition: Point2? {
        let tessellated = segment.tessellated()
        let t = tessellated.approxPathParamT(lineParamT: 0.5).t
        return segment.position(paramT: t)
    }

    private func subtractingCircle(at point: Point2) -> SUPath {
        SUPath { $0.addEllipse(in: CGRect(center: point, size: CGSize(squared: Self.circleSize))) }
    }

    @ViewBuilder private func circle(at point: Point2, color: Color) -> some View {
        Circle()
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth))
            .fill(color.opacity(0.5))
            .frame(width: Self.circleSize, height: Self.circleSize)
            .padding(Self.touchablePadding)
            .invisibleSoildOverlay()
            .position(point)
            .if(focused) { $0.overlay {
                SUPath { p in
                    let tessellated = segment.tessellated()
                    let fromT = tessellated.approxPathParamT(lineParamT: 0.1).t
                    let toT = tessellated.approxPathParamT(lineParamT: 0.9).t
                    segment.subsegment(fromT: fromT, toT: toT).append(to: &p)
                }
                .strokedPath(StrokeStyle(lineWidth: 2, lineCap: .round))
                .subtracting(subtractingCircle(at: point))
                .fill(color)
                .allowsHitTesting(false)
            }}
            .modifier(gesture(origin: point))
    }

    private func gesture(origin: Point2) -> MultipleGestureModifier<Point2> {
        func update(pending: Bool = false) -> (DragGesture.Value, Point2) -> Void {
            { value, origin in updater.updateActivePath(moveEdge: fromId, offsetInView: origin.offset(to: value.location), pending: pending) }
        }
        return MultipleGestureModifier(origin, onDrag: update(pending: true), onDragEnd: update())
    }
}
