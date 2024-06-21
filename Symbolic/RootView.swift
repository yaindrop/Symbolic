import SwiftUI

struct RootView: View, TracedView {
    var body: some View { trace {
        NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
            SidebarView()
        } detail: {
            DocumentsView()
        }
    }}
}

struct DocumentsView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var syncNotify: Bool { true }
        @Selected({ global.panel.movingPanelMap }) var movingPanelMap
    }

    @SelectorWrapper var selector

    @State private var sidebarType: SidebarType = .document
    @State private var isPresenting = false

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

extension DocumentsView {
    var data: [Int] { Array(1 ... 20) }

    var adaptiveColumn: [GridItem] {
        [
            GridItem(.adaptive(minimum: 150)),
        ]
    }

    var content: some View {
        ZStack {
            ScrollView {
                VStack {
                    Button("Canvas!") { isPresenting.toggle() }
                        .fullScreenCover(isPresented: $isPresenting) {
                            CanvasView()
                        }
                    LazyVGrid(columns: adaptiveColumn, spacing: 20) {
                        ForEach(data, id: \.self) { item in
                            Text(String(item))
                                .frame(width: 150, height: 150, alignment: .center)
                                .background(.blue)
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .font(.title)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Documents")
        }
    }
}

enum SidebarType: CaseIterable, SelfIdentifiable {
    case document, panel
}

struct SidebarView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var syncNotify: Bool { true }
        @Selected({ global.panel.movingPanelMap }) var movingPanelMap
    }

    @SelectorWrapper var selector

    @State private var sidebarType: SidebarType = .document

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension SidebarView {
    @ViewBuilder var content: some View {
        ScrollView {
            documents
        }
    }

    var documents: some View {
        VStack(spacing: 0) {
            Text("No documents")
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(12)
        }
        .navigationTitle("Symbolic")
    }
}
