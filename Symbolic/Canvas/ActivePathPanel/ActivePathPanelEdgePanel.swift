import Foundation
import SwiftUI

struct ActivePathPanelEdgePanel: View {
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
                            .font(.body)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(6)
                Group {
                    if case let .Bezier(bezier) = edge {
                        BezierPanel(fromNodeId: fromNodeId, bezier: bezier)
                    } else if case let .Arc(arc) = edge {
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

    private var focused: Bool { activePathModel.focusedPart?.id == fromNodeId }

    private var name: String {
        switch edge {
        case .Arc: return "Arc"
        case .Bezier: return "Bezier"
        case .Line: return "Line"
        }
    }
}

// MARK: - PathEdge panels

fileprivate struct BezierPanel: View {
    let fromNodeId: UUID
    let bezier: PathBezier

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "1.square")
                Spacer(minLength: 12)
                PositionPicker(position: bezier.control0) {
                    updater.updateActivePath(edge: fromNodeId, bezier: bezier.with(control0: $0), pending: true)
                } onDone: {
                    updater.updateActivePath(edge: fromNodeId, bezier: bezier.with(control0: $0))
                }
            }
            Divider()
            HStack {
                Image(systemName: "2.square")
                Spacer(minLength: 12)
                PositionPicker(position: bezier.control1) {
                    updater.updateActivePath(edge: fromNodeId, bezier: bezier.with(control1: $0), pending: true)
                } onDone: {
                    updater.updateActivePath(edge: fromNodeId, bezier: bezier.with(control1: $0))
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    @EnvironmentObject private var updater: PathUpdater
}

fileprivate struct ArcPanel: View {
    let fromNodeId: UUID
    let arc: PathArc

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Radius")
                Spacer()
                SizePicker(size: arc.radius) {
                    updater.updateActivePath(edge: fromNodeId, arc: arc.with(radius: $0), pending: true)
                } onDone: {
                    updater.updateActivePath(edge: fromNodeId, arc: arc.with(radius: $0))
                }
            }
            Divider()
            HStack {
                Text("Rotation")
                Spacer()
                AnglePicker(angle: arc.rotation) {
                    updater.updateActivePath(edge: fromNodeId, arc: arc.with(rotation: $0), pending: true)
                } onDone: {
                    updater.updateActivePath(edge: fromNodeId, arc: arc.with(rotation: $0))
                }
            }
            Divider()
            HStack {
                Text("Large Arc")
                Spacer()
                Text("\(arc.largeArc)")
            }
            Divider()
            HStack {
                Text("Sweep")
                Spacer()
                Text("\(arc.sweep)")
            }
        }
        .padding(12)
        .background(Color.secondarySystemBackground)
        .cornerRadius(12)
    }

    @EnvironmentObject private var updater: PathUpdater
}
