import SwiftUI

private extension GlobalStores {
    func setupDocumentFlow() {
        root.holdCancellables {
            document.store.$activeDocument.didSet
                .sink {
                    root.asyncSave(document: $0)
                    path.loadDocument($0)
                    pathProperty.loadDocument($0)
                    item.loadDocument($0)
                }
            document.store.$pendingEvent.didSet
                .sink {
                    path.loadPendingEvent($0)
                    pathProperty.loadPendingEvent($0)
                    item.loadPendingEvent($0)
                }
        }
    }

    func setupDocumentUpdaterFlow() {
        document.store.holdCancellables {
            documentUpdater.store.pendingEventPublisher
                .sink {
                    document.setPendingEvent($0)
                }
            documentUpdater.store.eventPublisher
                .sink {
                    document.sendEvent($0)
                }
        }
    }
}

enum RootNavigationValue: CaseIterable, SelfIdentifiable {
    case documents
    case deleted
}

// MARK: - RootView

struct RootView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(animation: .fast, { global.root.showCanvas }) var showCanvas
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
                .onAppear {
                    try! URL.deletedDirectory.create()
                    global.setupDocumentFlow()
                    global.setupDocumentUpdaterFlow()
                    global.root.loadFileTree(at: .documentDirectory)
                }
                .onOpenURL {
                    global.root.open(documentAt: $0)
                }
        }
    }}
}

// MARK: private

private extension RootView {
    var content: some View {
        ZStack {
            NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
                SidebarView()
            } detail: {
                NavigationStack {
                    DocumentsView()
                }
            }
            if selector.showCanvas {
                CanvasView()
                    .background(.background)
            }
        }
    }
}

// MARK: - DocumentsView

struct DocumentsView: View, TracedView {
    @State private var path: [URL] = []

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension DocumentsView {
    @ViewBuilder var content: some View {
        NavigationStack(path: $path) {
            DirectoryView(path: $path, url: .documentDirectory)
                .navigationDestination(for: URL.self) {
                    DirectoryView(path: $path, url: $0)
                }
        }
    }
}

// MARK: - DeletedView

struct DeletedView: View, TracedView {
    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension DeletedView {
    @ViewBuilder var content: some View {
        DirectoryView(path: .constant([]), url: .deletedDirectory)
    }
}
