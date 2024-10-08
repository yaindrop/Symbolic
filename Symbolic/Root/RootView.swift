import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func setupDocumentFlow() {
        document.store.holdCancellables {
            $0.$activeDocument.didSet
                .sink {
                    fileBrowser.asyncSave(document: $0)
                    path.load(document: $0)
                    symbol.load(document: $0)
                    item.load(document: $0)
                    world.load(document: $0)
                }
            $0.$pendingEvent.didSet
                .sink {
                    path.load(pendingEvent: $0)
                    symbol.load(pendingEvent: $0)
                    item.load(pendingEvent: $0)
                    world.load(pendingEvent: $0)
                }
        }
    }

    func setupDocumentUpdaterFlow() {
        documentUpdater.store.holdCancellables {
            $0.$pendingEvent
                .sink {
                    document.setPendingEvent($0)
                }
            $0.$event
                .sink {
                    document.sendEvent($0)
                }
        }
    }
}

// MARK: - RootView

struct RootView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.fileBrowser.activeDocument != nil }, .animation(.faster)) var showCanvas
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
                .onAppear {
                    try! URL.deletedDirectory.create()
                    global.setupDocumentFlow()
                    global.setupDocumentUpdaterFlow()
                    global.fileBrowser.loadFileTree(at: .documentDirectory)
                }
                .onOpenURL {
                    guard let entry = FileEntry(url: $0) else { return }
                    global.fileBrowser.open(at: entry)
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
                FileBrowserView()
                    .sizeReader { global.root.setDetailSize($0) }
            }
            .sizeReader { global.root.setNavigationSize($0) }
            .zIndex(0)
            if selector.showCanvas {
                CanvasView()
                    .background(.background)
                    .zIndex(1)
            }
        }
    }
}

// MARK: - SidebarView

struct SidebarView: View, TracedView {
    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension SidebarView {
    @ViewBuilder var content: some View {
        ScrollView {
            VStack {
                ForEach(RootNavigationValue.allCases) {
                    SidebarItem(value: $0)
                }
            }
            .padding()
        }
        .navigationDestination(for: RootNavigationValue.self) { value in
            switch value {
            case .documents: SidebarDestination(value: value) { FileBrowserView() }
            case .deleted: SidebarDestination(value: value) { DeletedFileBrowserView() }
            }
        }
        .navigationTitle("Symbolic")
    }
}

// MARK: - SidebarDestination

struct SidebarDestination<Content: View>: View {
    let value: RootNavigationValue
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .onAppear { global.root.setSelected(value) }
            .sizeReader { global.root.setDetailSize($0) }
    }
}

// MARK: - SidebarItem

struct SidebarItem: View, SelectorHolder {
    let value: RootNavigationValue

    class Selector: SelectorBase {
        @Selected({ global.root.selected }) var selected
    }

    @SelectorWrapper var selector
    var body: some View {
        setupSelector {
            content
        }
    }
}

// MARK: private

private extension SidebarItem {
    var isSelected: Bool { selector.selected == value }

    var imageName: String {
        switch value {
        case .documents: "folder.circle"
        case .deleted: "trash.circle"
        }
    }

    var imageTint: Color {
        switch value {
        case .documents: .blue
        case .deleted: .red
        }
    }

    var name: String {
        switch value {
        case .documents: "Documents"
        case .deleted: "Deleted"
        }
    }

    var content: some View {
        NavigationLink(value: value) {
            HStack {
                Image(systemName: imageName)
                    .font(.title)
                    .tint(imageTint)
                Text(name)
                    .font(.title3)
                Spacer()
            }
            .tint(.label)
            .padding(12)
            .background(isSelected ? Color.secondarySystemBackground : .clear)
            .clipRounded(radius: 12)
        }
    }
}
