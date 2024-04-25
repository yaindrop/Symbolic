import Combine
import Foundation
import SwiftUI

fileprivate struct PathNodeIdEnvironmentKey: EnvironmentKey {
    static let defaultValue: UUID = UUID()
}

fileprivate extension EnvironmentValues {
    var pathNodeId: UUID {
        get { self[PathNodeIdEnvironmentKey.self] }
        set { self[PathNodeIdEnvironmentKey.self] = newValue }
    }
}

// MARK: - ActivePathView

struct ActivePathView: View {
    @ObservedObject var activePathModel: ActivePathModel

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
        .environmentObject(activePathModel)
    }

    // MARK: private

    private var title: some View {
        HStack {
            Spacer()
            Text("Active Path")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
            Spacer()
        }
    }

    private func segmentTitle(_ title: String) -> some View {
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

    @State var expanded = false

    var name: String {
        switch edge {
        case .Arc: return "Arc"
        case .Bezier: return "Bezier"
        case .Line: return "Line"
        }
    }

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
            PositionPicker(position: node.position)
        }
        .padding(12)
        .background(.ultraThickMaterial)
        .cornerRadius(12)
    }
}

// MARK: - PathEdge panels

fileprivate struct BezierPanel: View {
    var bezier: PathBezier
    @EnvironmentObject var documentModel: DocumentModel
    @EnvironmentObject var pathModel: PathModel
    @EnvironmentObject var activePathModel: ActivePathModel
    @Environment(\.pathNodeId) var nodeId

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "1.square")
                Spacer(minLength: 12)
                PositionPicker(position: bezier.control0) { p in
                    let bezier = PathBezier(control0: bezier.control0, control1: p)
                    let event = DocumentEvent(inPath: activePathModel.activePathId!, updateEdgeFrom: nodeId, .Bezier(bezier))
                    documentModel.activeDocument = Document(events: documentModel.activeDocument.events + [event])
                } onDone: { p in
                    let bezier = PathBezier(control0: bezier.control0, control1: p)
                    let event = DocumentEvent(inPath: activePathModel.activePathId!, updateEdgeFrom: nodeId, .Bezier(bezier))
                    documentModel.activeDocument = Document(events: documentModel.activeDocument.events + [event])
                }
            }
            Divider()
            HStack {
                Image(systemName: "2.square")
                Spacer(minLength: 12)
                PositionPicker(position: bezier.control1) { p in
                    let bezier = PathBezier(control0: p, control1: bezier.control1)
                    let event = DocumentEvent(inPath: activePathModel.activePathId!, updateEdgeFrom: nodeId, .Bezier(bezier))
                    documentModel.activeDocument = Document(events: documentModel.activeDocument.events + [event])
                } onDone: { p in
                    let bezier = PathBezier(control0: p, control1: bezier.control1)
                    let event = DocumentEvent(inPath: activePathModel.activePathId!, updateEdgeFrom: nodeId, .Bezier(bezier))
                    documentModel.activeDocument = Document(events: documentModel.activeDocument.events + [event])
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

fileprivate struct ArcPanel: View {
    var arc: PathArc

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Radius")
                Spacer()
                SizePicker(size: arc.radius)
            }
            Divider()
            HStack {
                Text("Rotation")
                Spacer()
                AnglePicker(angle: arc.rotation)
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
}
