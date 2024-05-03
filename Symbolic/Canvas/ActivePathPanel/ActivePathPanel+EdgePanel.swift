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
                        Button {
                            withAnimation { expanded.toggle() }
                        } label: {
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            Text(name)
                                .font(.subheadline)
                        }
                        .if(focused) { $0.foregroundStyle(.cyan) }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(6)
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
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .onChange(of: focused) {
                    withAnimation { expanded = focused }
                }
            }
        }

        @EnvironmentObject private var activePathModel: ActivePathModel
        @State private var expanded = false

        private var focused: Bool { activePathModel.focusedPart == .edge(fromNodeId) }

        private var name: String {
            switch edge {
            case .arc: "Arc"
            case .bezier: "Bezier"
            case .line: "Line"
            }
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
                Image(systemName: "1.square")
                Spacer(minLength: 12)
                PositionPicker(position: bezier.control0, onChange: updateControl0(pending: true), onDone: updateControl0())
            }
            Divider()
            HStack {
                Image(systemName: "2.square")
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
                    .font(.callout)
                Spacer()
                SizePicker(size: arc.radius, onChange: updateRadius(pending: true), onDone: updateRadius())
            }
            Divider()
            HStack {
                Text("Rotation")
                    .font(.callout)
                Spacer()
                AnglePicker(angle: arc.rotation, onChange: updateRotation(pending: true), onDone: updateRotation())
            }
            Divider()
            HStack {
                Text("Large Arc")
                    .font(.callout)
                Spacer()
                FlagInput(flag: arc.largeArc, onChange: updateLargeArc)
            }
            Divider()
            HStack {
                Text("Sweep")
                    .font(.callout)
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
