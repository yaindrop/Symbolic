import Foundation
import SwiftUI

fileprivate extension DocumentEvent {
    var name: String {
        switch kind {
        case .compoundEvent:
            return "Compound"
        case .pathEvent:
            return "Path"
        }
    }
}

// MARK: - HistoryPanel

struct HistoryPanel: View {
    var body: some View {
        VStack {
            Spacer()
            Group {
                VStack(spacing: 0) {
                    title
                    content
                }
            }
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .frame(maxWidth: 360, maxHeight: 480)
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

    @ViewBuilder var content: some View {
        let document = documentModel.activeDocument
        ScrollViewReader { _ in
            ScrollView {
                VStack(spacing: 4) {
                    sectionTitle("Components")
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
                .scrollOffsetReader(model: scrollOffset)
            }
//            .onChange(of: activePathModel.focusedPart) {
//                guard let id = activePathModel.focusedPart?.id else { return }
//                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
//            }
        }
        .scrollOffsetProvider(model: scrollOffset)
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
    }
}
