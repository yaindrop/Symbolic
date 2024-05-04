import Foundation
import SwiftUI

extension ActivePathPanel {
    // MARK: - EdgePanel

    struct EdgePanel: View {
        let fromNodeId: UUID
        let edge: PathEdge

        var body: some View {
            HStack {
                Spacer(minLength: 24)
                VStack(spacing: 0) {
                    HStack {
                        titleMenu
                        Spacer()
                        expandButton
                    }
                    edgeKindPanel
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .onChange(of: focused) {
                    withAnimation { expanded = focused }
                }
            }
        }

        @EnvironmentObject private var activePathModel: ActivePathModel
        @EnvironmentObject private var updater: PathUpdater
        @State private var expanded = false

        private var focused: Bool { activePathModel.focusedPart == .edge(fromNodeId) }

        private var name: String {
            switch edge {
            case .arc: "Arc"
            case .bezier: "Bezier"
            case .line: "Line"
            }
        }

        private func deleteEdge() {
            updater.updateActivePath(deleteEdge: fromNodeId)
        }

        @ViewBuilder private var title: some View {
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                Text(name)
                    .font(.subheadline)
            }
            .if(focused) { $0.foregroundStyle(.cyan) }
            .padding(6)
        }

        @ViewBuilder private var titleMenu: some View {
            Menu {
                Button(focused ? "Unfocus" : "Focus") {
                    focused ? activePathModel.clearFocus() : activePathModel.setFocus(edge: fromNodeId)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    deleteEdge()
                }
            } label: {
                title
            }
            .buttonStyle(PlainButtonStyle())
        }

        @ViewBuilder private var expandButton: some View {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
        }

        @ViewBuilder private var edgeKindPanel: some View {
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
    }
}

// MARK: - BezierPanel

fileprivate struct BezierPanel: View {
    let fromNodeId: UUID
    let bezier: PathEdge.Bezier

    var body: some View {
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
    }

    @EnvironmentObject private var updater: PathUpdater

    private func updateControl0(pending: Bool = false) -> (Point2) -> Void {
        { updater.updateActivePath(edge: fromNodeId, bezier: bezier.with(control0: $0), pending: pending) }
    }

    private func updateControl1(pending: Bool = false) -> (Point2) -> Void {
        { updater.updateActivePath(edge: fromNodeId, bezier: bezier.with(control1: $0), pending: pending) }
    }
}

// MARK: - ArcPanel

fileprivate struct ArcPanel: View {
    let fromNodeId: UUID
    let arc: PathEdge.Arc

    var body: some View {
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

    @EnvironmentObject private var updater: PathUpdater

    private func updateRadius(pending: Bool = false) -> (CGSize) -> Void {
        { updater.updateActivePath(edge: fromNodeId, arc: arc.with(radius: $0), pending: pending) }
    }

    private func updateRotation(pending: Bool = false) -> (Angle) -> Void {
        { updater.updateActivePath(edge: fromNodeId, arc: arc.with(rotation: $0), pending: pending) }
    }

    private var updateLargeArc: (Bool) -> Void {
        { updater.updateActivePath(edge: fromNodeId, arc: arc.with(largeArc: $0)) }
    }

    private var updateSweep: (Bool) -> Void {
        { updater.updateActivePath(edge: fromNodeId, arc: arc.with(sweep: $0)) }
    }
}
