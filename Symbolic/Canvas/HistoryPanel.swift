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
        VStack {
            Spacer()
            VStack(spacing: 0) {
                title
                scrollView
            }
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .frame(maxWidth: 320, maxHeight: 480)
        .padding(24)
        .atCornerPosition(.bottomLeft)
    }

    // MARK: private

    @EnvironmentObject private var documentModel: DocumentModel

    @ViewBuilder private var title: some View {
        HStack {
            Spacer()
            Text("History")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
            Spacer()
        }
        .padding(12)
        .if(scrollOffset.scrolled) { $0.background(.regularMaterial) }
    }

    @ViewBuilder private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
                .padding(.leading, 12)
            Spacer()
        }
    }

    @StateObject private var scrollOffset = ScrollOffsetModel()

    @ViewBuilder var scrollView: some View {
        ScrollViewReader { _ in
            ScrollViewWithOffset(model: scrollOffset) {
                content
            }
//            .onChange(of: activePathModel.focusedPart) {
//                guard let id = activePathModel.focusedPart?.id else { return }
//                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
//            }
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
            sectionTitle("Events")
            VStack(spacing: 12) {
//                        ForEach(activePath.segments) { segment in
//                            NodeEdgeGroup(segment: segment)
//                        }
                ForEach(document.events) { e in
                    Text("\(e.name)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}
