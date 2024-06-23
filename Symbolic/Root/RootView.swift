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
                    global.setupDocumentFlow()
                    global.setupDocumentUpdaterFlow()
                    global.root.loadFileTree()
                }
                .onOpenURL {
                    global.root.open(documentFrom: $0)
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
                DocumentsView()
            }
            if selector.showCanvas {
                CanvasView()
                    .background(.background)
            }
        }
    }
}
