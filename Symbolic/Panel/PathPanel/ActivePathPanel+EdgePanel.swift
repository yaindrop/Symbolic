import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - EdgePanel

    struct EdgePanel: View, EquatableBy {
        let path: Path
        let property: PathProperty
        let focusedPart: PathFocusedPart?

        let fromNodeId: UUID

        var segment: PathSegment? { path.segment(from: fromNodeId) }
        var focused: Bool { focusedPart?.edgeId == fromNodeId }

        var equatableBy: some Equatable { fromNodeId; segment; focused }

        var body: some View { tracer.range("ActivePathPanel EdgePanel body") {
            HStack {
                Spacer(minLength: 24)
                VStack(spacing: 0) {
                    header
                    edgeKindPanel
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipRounded(radius: 12)
                .onChange(of: focused) {
                    withAnimation { expanded = focused }
                }
            }
        }}

        @State private var expanded = false

        private var name: String {
            "Edge"
        }

        @ViewBuilder private var header: some View { tracer.range("ActivePathPanel EdgePanel header") {
            HStack {
                titleMenu
                Spacer()
                expandButton
            }
        } }

        @ViewBuilder private var title: some View { tracer.range("ActivePathPanel EdgePanel title") {
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                Text(name)
                    .font(.subheadline)
            }
            .if(focused) { $0.foregroundStyle(.cyan) }
            .padding(6)
        }}

        @ViewBuilder private var titleMenu: some View { tracer.range("ActivePathPanel EdgePanel titleMenu \(fromNodeId)") {
            Memo {
                Menu {
                    Label("\(fromNodeId)", systemImage: "number")
                    Button(focused ? "Unfocus" : "Focus", systemImage: focused ? "circle.slash" : "scope") { toggleFocus() }
                    Divider()
                    Button("Split", systemImage: "square.and.line.vertical.and.square") { splitEdge() }
                    Divider()
                    Button("Break", systemImage: "trash", role: .destructive) { breakEdge() }
                } label: {
                    title
                }
                .tint(.label)
            } deps: { fromNodeId; focused }
        }}

        @ViewBuilder private var expandButton: some View {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .padding(6)
            }
            .tint(.label)
        }

        @ViewBuilder private var edgeKindPanel: some View { tracer.range("ActivePathPanel EdgePanel edgeKindPanel") {
            Memo {
                Group {
                    if let segment {
                        BezierPanel(fromNodeId: fromNodeId, edge: segment.edge)
                    }
                }
                .padding(.top, 6)
                .frame(height: expanded ? nil : 0, alignment: .top)
                .clipped()
            } deps: { segment; expanded }
        } }

        private func toggleFocus() {
            focused ? global.activeItem.clearFocus() : global.activeItem.setFocus(edge: fromNodeId)
        }

        private func splitEdge() {
            guard let segment else { return }
            let paramT = segment.tessellated().approxPathParamT(lineParamT: 0.5).t
            let id = UUID()
            global.documentUpdater.update(activePath: .splitSegment(.init(fromNodeId: fromNodeId, paramT: paramT, newNodeId: id, offset: .zero)))
            global.activeItem.setFocus(node: id)
        }

        private func breakEdge() {
            if let activePathId = global.activeItem.focusedItemId {
                global.documentUpdater.update(path: .breakAtEdge(.init(pathId: activePathId, fromNodeId: fromNodeId, newPathId: UUID())))
            }
        }
    }
}

// MARK: - BezierPanel

private struct BezierPanel: View, EquatableBy {
    let fromNodeId: UUID
    let edge: PathEdge

    var equatableBy: some Equatable { fromNodeId; edge }

    var body: some View { tracer.range("ActivePathPanel EdgePanel BezierPanel") {
        VStack(spacing: 12) {
            HStack {
                Text("C₁")
                    .font(.callout.monospacedDigit())
                Spacer(minLength: 12)
                PositionPicker(position: Point2(edge.control0), onChange: updateControl0(pending: true), onDone: updateControl0())
            }
            Divider()
            HStack {
                Text("C₂")
                    .font(.callout.monospacedDigit())
                Spacer(minLength: 12)
                PositionPicker(position: Point2(edge.control1), onChange: updateControl1(pending: true), onDone: updateControl1())
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipRounded(radius: 12)
    }}

    private func updateControl0(pending: Bool = false) -> (Point2) -> Void {
        { global.documentUpdater.update(activePath: .setEdge(.init(fromNodeId: fromNodeId, edge: edge.with(control0: Vector2($0)))), pending: pending) }
    }

    private func updateControl1(pending: Bool = false) -> (Point2) -> Void {
        { global.documentUpdater.update(activePath: .setEdge(.init(fromNodeId: fromNodeId, edge: edge.with(control1: Vector2($0)))), pending: pending) }
    }
}
