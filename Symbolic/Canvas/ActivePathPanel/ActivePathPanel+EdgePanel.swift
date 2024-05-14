import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - EdgePanel

    struct EdgePanel: View, EnableActivePathInteractor, EnablePathUpdater {
        @Environment(PathModel.self) var pathModel: PathModel
        @Environment(PendingPathModel.self) var pendingPathModel: PendingPathModel
        @Environment(ActivePathModel.self) var activePathModel: ActivePathModel
        @Environment(PathUpdateModel.self) var pathUpdateModel: PathUpdateModel

        let fromNodeId: UUID
        let edge: PathEdge

        var body: some View { tracer.range("ActivePathPanel EdgePanel body") {
            HStack {
                Spacer(minLength: 24)
                VStack(spacing: 0) {
                    header
                    edgeKindPanel
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .onChange(of: focused) {
                    withAnimation { expanded = focused }
                }
            }
        }}

        @State private var expanded = false

        private var focused: Bool { activePathInteractor.focusedPart == .edge(fromNodeId) }

        private var name: String {
            switch edge {
            case .arc: "Arc"
            case .bezier: "Bezier"
            case .line: "Line"
            }
        }

        @ViewBuilder private var header: some View { tracer.range("ActivePathPanel EdgePanel header") {
            HStack {
                titleMenu
                Spacer()
                if case .line = edge {} else {
                    expandButton
                }
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
            memo(edge) {
                Menu { tracer.range("ActivePathPanel EdgePanel titleMenu menu") {
                    Label("\(fromNodeId)", systemImage: "number")
                    Button(focused ? "Unfocus" : "Focus", systemImage: focused ? "circle.slash" : "scope") { toggleFocus() }
                    Divider()
                    ControlGroup {
                        Button("Arc", systemImage: "circle") { changeEdge(to: .arc) }
                            .disabled(edge.case == .arc)
                        Button("Bezier", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") { changeEdge(to: .bezier) }
                            .disabled(edge.case == .bezier)
                        Button("Line", systemImage: "chart.xyaxis.line") { changeEdge(to: .line) }
                            .disabled(edge.case == .line)
                    } label: {
                        Text("Type")
                    }
                    Button("Split", systemImage: "square.and.line.vertical.and.square") { splitEdge() }
                    Divider()
                    Button("Break", systemImage: "trash", role: .destructive) { breakEdge() }
                }} label: {
                    title
                }
                .tint(.label)
            }
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
            memo(deps: .init(expanded, edge)) {
                Group {
                    if case let .bezier(bezier) = edge {
                        BezierPanel(fromNodeId: fromNodeId, bezier: bezier)
                    } else if case let .arc(arc) = edge {
                        ArcPanel(fromNodeId: fromNodeId, arc: arc)
                    }
                }
                .padding(.top, 6)
                .frame(height: expanded ? nil : 0, alignment: .top)
                .clipped()
            }
        } }

        private func toggleFocus() {
            focused ? activePathInteractor.clearFocus() : activePathInteractor.setFocus(edge: fromNodeId)
        }

        private func changeEdge(to: PathEdge.Case) {
            pathUpdater.updateActivePath(changeEdge: fromNodeId, to: to)
        }

        private func splitEdge() {
            guard let segment = activePathInteractor.activePath?.segment(from: fromNodeId) else { return }
            let paramT = segment.tessellated().approxPathParamT(lineParamT: 0.5).t
            let position = segment.position(paramT: paramT)
            let id = UUID()
            pathUpdater.updateActivePath(splitSegment: fromNodeId, paramT: paramT, newNodeId: id, position: position)
            activePathInteractor.setFocus(node: id)
        }

        private func breakEdge() {
            pathUpdater.updateActivePath(deleteEdge: fromNodeId)
        }
    }
}

// MARK: - BezierPanel

fileprivate struct BezierPanel: View, EnableActivePathInteractor, EnablePathUpdater {
    @Environment(PathModel.self) var pathModel: PathModel
    @Environment(PendingPathModel.self) var pendingPathModel: PendingPathModel
    @Environment(ActivePathModel.self) var activePathModel: ActivePathModel
    @Environment(PathUpdateModel.self) var pathUpdateModel: PathUpdateModel

    let fromNodeId: UUID
    let bezier: PathEdge.Bezier

    var body: some View {
        memo(bezier) { tracer.range("ActivePathPanel EdgePanel BezierPanel") {
            VStack(spacing: 12) {
                HStack {
                    Text("C₁")
                        .font(.callout.monospacedDigit())
                    Spacer(minLength: 12)
                    PositionPicker(position: bezier.control0, onChange: updateControl0(pending: true), onDone: updateControl0())
                }
                Divider()
                HStack {
                    Text("C₂")
                        .font(.callout.monospacedDigit())
                    Spacer(minLength: 12)
                    PositionPicker(position: bezier.control1, onChange: updateControl1(pending: true), onDone: updateControl1())
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .cornerRadius(12)
        }}
    }

    private func updateControl0(pending: Bool = false) -> (Point2) -> Void {
        { pathUpdater.updateActivePath(edge: fromNodeId, bezier: bezier.with(control0: $0), pending: pending) }
    }

    private func updateControl1(pending: Bool = false) -> (Point2) -> Void {
        { pathUpdater.updateActivePath(edge: fromNodeId, bezier: bezier.with(control1: $0), pending: pending) }
    }
}

// MARK: - ArcPanel

fileprivate struct ArcPanel: View, EnableActivePathInteractor, EnablePathUpdater {
    @Environment(PathModel.self) var pathModel: PathModel
    @Environment(PendingPathModel.self) var pendingPathModel: PendingPathModel
    @Environment(ActivePathModel.self) var activePathModel: ActivePathModel
    @Environment(PathUpdateModel.self) var pathUpdateModel: PathUpdateModel

    let fromNodeId: UUID
    let arc: PathEdge.Arc

    var body: some View { tracer.range("ActivePathPanel EdgePanel ArcPanel") {
        memo(arc) {
            VStack(spacing: 12) {
                HStack {
                    Text("Radius")
                        .font(.subheadline)
                    Spacer()
                    SizePicker(size: arc.radius, onChange: updateRadius(pending: true), onDone: updateRadius())
                }
                Divider()
                HStack {
                    Text("Rotation")
                        .font(.subheadline)
                    Spacer()
                    AnglePicker(angle: arc.rotation, onChange: updateRotation(pending: true), onDone: updateRotation())
                }
                Divider()
                HStack {
                    Text("Large Arc")
                        .font(.subheadline)
                    Spacer()
                    FlagInput(flag: arc.largeArc, onChange: updateLargeArc)
                }
                Divider()
                HStack {
                    Text("Sweep")
                        .font(.subheadline)
                    Spacer()
                    FlagInput(flag: arc.sweep, onChange: updateSweep)
                }
            }
            .padding(12)
            .background(Color.secondarySystemBackground)
            .cornerRadius(12)
        }
    }}

    private func updateRadius(pending: Bool = false) -> (CGSize) -> Void {
        { pathUpdater.updateActivePath(edge: fromNodeId, arc: arc.with(radius: $0), pending: pending) }
    }

    private func updateRotation(pending: Bool = false) -> (Angle) -> Void {
        { pathUpdater.updateActivePath(edge: fromNodeId, arc: arc.with(rotation: $0), pending: pending) }
    }

    private var updateLargeArc: (Bool) -> Void {
        { pathUpdater.updateActivePath(edge: fromNodeId, arc: arc.with(largeArc: $0)) }
    }

    private var updateSweep: (Bool) -> Void {
        { pathUpdater.updateActivePath(edge: fromNodeId, arc: arc.with(sweep: $0)) }
    }
}
