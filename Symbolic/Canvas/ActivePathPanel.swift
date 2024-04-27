import Combine
import Foundation
import SwiftUI

fileprivate extension EnvironmentValues {
    struct PathNodeIdKey: EnvironmentKey {
        static let defaultValue = UUID()
    }

    var pathNodeId: UUID {
        get { self[PathNodeIdKey.self] }
        set { self[PathNodeIdKey.self] = newValue }
    }
}

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    @EnvironmentObject var pathStore: PathStore
    @EnvironmentObject var activePathModel: ActivePathModel

    var body: some View {
        VStack {
            Spacer()
            Group {
                VStack(spacing: 0) {
                    title
                        .padding(12)
                        .if(scrollOffset.scrolled) { $0.background(.regularMaterial) }
                    components
                }
            }
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .frame(maxWidth: 360, maxHeight: 480)
        .padding(24)
        .modifier(CornerPositionModifier(position: .bottomRight))
    }

    // MARK: private

    @ViewBuilder private var title: some View {
        HStack {
            Spacer()
            Text("Active Path")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
            Spacer()
        }
    }

    @ViewBuilder private func segmentTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
                .padding(.leading, 12)
            Spacer()
        }
    }

    @StateObject private var scrollOffset = ScrollOffsetModel()

    @ViewBuilder private var components: some View {
        if let activePath = activePathModel.activePath {
            ScrollView {
                VStack(spacing: 4) {
                    segmentTitle("Components")
                    LazyVStack(spacing: 12) {
                        ForEach(activePath.segments) { segment in
                            Group {
                                NodePanel(index: segment.index, node: segment.from)
                                EdgePanel(edge: segment.edge)
                            }
                            .environment(\.pathNodeId, segment.from.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .scrollOffsetReader(model: scrollOffset)
            }
            .scrollOffsetProvider(model: scrollOffset)
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}

// MARK: - Component rows

fileprivate struct EdgePanel: View {
    let edge: PathEdge

    var body: some View {
        HStack {
            Spacer(minLength: 24)
            VStack(spacing: 0) {
                HStack {
                    Button {
                        withAnimation {
                            expanded.toggle()
                        }
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
                        BezierPanel(bezier: bezier)
                    } else if case let .Arc(arc) = edge {
                        ArcPanel(arc: arc)
                    }
                }
                .padding(.top, 6)
                .frame(height: expanded ? nil : 0, alignment: .top)
                .clipped()
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }

    @State private var expanded = false

    private var name: String {
        switch edge {
        case .Arc: return "Arc"
        case .Bezier: return "Bezier"
        case .Line: return "Line"
        }
    }
}

fileprivate struct NodePanel: View {
    let index: Int
    let node: PathNode

    var body: some View {
        HStack {
            Image(systemName: "smallcircle.filled.circle")
            Text("\(index)")
                .font(.headline)
            Spacer()
            PositionPicker(position: node.position) {
                updater.activePathPanel(node: nodeId, with: $0, pending: true)
            } onDone: {
                updater.activePathPanel(node: nodeId, with: $0)
            }
        }
        .padding(12)
        .background(.ultraThickMaterial)
        .cornerRadius(12)
    }

    @EnvironmentObject private var updater: PathUpdater
    @Environment(\.pathNodeId) private var nodeId
}

// MARK: - PathEdge panels

fileprivate struct BezierPanel: View {
    let bezier: PathBezier

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "1.square")
                Spacer(minLength: 12)
                PositionPicker(position: bezier.control0) {
                    updater.activePathPanel(edge: nodeId, with: bezier.with(control0: $0), pending: true)
                } onDone: {
                    updater.activePathPanel(edge: nodeId, with: bezier.with(control0: $0))
                }
            }
            Divider()
            HStack {
                Image(systemName: "2.square")
                Spacer(minLength: 12)
                PositionPicker(position: bezier.control1) {
                    updater.activePathPanel(edge: nodeId, with: bezier.with(control1: $0), pending: true)
                } onDone: {
                    updater.activePathPanel(edge: nodeId, with: bezier.with(control1: $0))
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    @EnvironmentObject private var updater: PathUpdater
    @Environment(\.pathNodeId) private var nodeId
}

fileprivate struct ArcPanel: View {
    let arc: PathArc

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Radius")
                Spacer()
                SizePicker(size: arc.radius) {
                    updater.activePathPanel(edge: nodeId, with: arc.with(radius: $0), pending: true)
                } onDone: {
                    updater.activePathPanel(edge: nodeId, with: arc.with(radius: $0))
                }
            }
            Divider()
            HStack {
                Text("Rotation")
                Spacer()
                AnglePicker(angle: arc.rotation) {
                    updater.activePathPanel(edge: nodeId, with: arc.with(rotation: $0), pending: true)
                } onDone: {
                    updater.activePathPanel(edge: nodeId, with: arc.with(rotation: $0))
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
    @Environment(\.pathNodeId) private var nodeId
}
