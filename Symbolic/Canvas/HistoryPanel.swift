import Foundation
import SwiftUI

fileprivate extension DocumentEvent {
    var name: String {
        switch action {
        case let .pathAction(pathAction):
            switch pathAction {
            case .load: "PathLoad"
            case let .moveEdge(moveEdge): "\(moveEdge.pathId) MoveEdge \(moveEdge.fromNodeId) offset \(moveEdge.offset)"
            default: "pathAction"
            }
        }
    }
}

// MARK: - HistoryPanel

struct HistoryPanel: View {
    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @EnvironmentObject private var documentModel: DocumentModel
    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @Environment(\.windowId) private var windowId
    @EnvironmentObject private var windowModel: WindowModel
    private var window: WindowData { windowModel.idToWindow[windowId]! }

    private var moveWindowGesture: MultipleGestureModifier<Point2> {
        MultipleGestureModifier(
            window.origin,
            configs: .init(coordinateSpace: .global),
            onDrag: { v, c in windowModel.onMoving(windowId: window.id, origin: c + v.offset) },
            onDragEnd: { v, c in windowModel.onMoved(windowId: window.id, origin: c + v.offset, inertia: v.inertia) }
        )
    }

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "History")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .modifier(moveWindowGesture)
            scrollView
        }
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { _ in
            content
        }
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
    }

    @ViewBuilder var content: some View {
        let document = documentModel.activeDocument
        VStack(spacing: 4) {
            Button {
                var events = document.events
                events.removeLast()
                documentModel.activeDocument = Document(events: events)
            } label: {
                Text("Undo")
            }
            PanelSectionTitle(name: "Events")
            VStack(spacing: 12) {
                ForEach(document.events) { e in
                    Text("\(e.name)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
