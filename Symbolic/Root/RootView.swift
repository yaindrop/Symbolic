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
        @Selected(animation: .fast, { global.root.activeDocument != nil }) var showCanvas
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
                .sizeReader { global.viewport.setViewSize($0) }
                .onAppear {
                    try! URL.deletedDirectory.create()
                    global.setupDocumentFlow()
                    global.setupDocumentUpdaterFlow()
                    global.root.loadFileTree(at: .documentDirectory)
                }
                .onOpenURL {
                    guard let entry = FileEntry(url: $0) else { return }
                    global.root.open(at: entry)
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

// MARK: - DocumentsView

struct DocumentsView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(animation: .default, { global.root.directories }) var directories
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension DocumentsView {
    @ViewBuilder var content: some View {
        ZStack {
            ForEach(selector.directories, id: \.path) {
                DirectoryView(url: $0)
                    .background(.background)
                    .transition(.slide)
            }
        }
        .modifier(DocumentsToolbarModifier())
    }
}

// MARK: - DocumentToolbarModifier

private struct DocumentsToolbarModifier: ViewModifier, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(alwaysNotify: true, { global.viewport.viewSize }) var viewSize
        @Selected(animation: .default, { global.root.isSelectingFiles }) var isSelectingFiles
    }

    @SelectorWrapper var selector

    func body(content: Content) -> some View {
        setupSelector {
            let _ = selector.viewSize // strange bug that toolbar is lost when window size changes, need to reset ids
            content.toolbar { toolbar }
        }
    }

    @ToolbarContentBuilder var toolbar: some ToolbarContent {
        ToolbarItem(id: UUID().uuidString, placement: .topBarLeading) { leading }
        ToolbarItem(id: UUID().uuidString, placement: .topBarTrailing) { trailing }
        if selector.isSelectingFiles {
            ToolbarItem(id: UUID().uuidString, placement: .bottomBar) { bottomBar }
        }
    }

    var leading: some View {
        HStack {
            Button {
                global.root.directoryBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(global.root.directoryPath.isEmpty)
            .frame(size: .init(squared: 36))
            Button {
                global.root.directoryForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(global.root.forwardPath.isEmpty)
            .frame(size: .init(squared: 36))
        }
    }

    var trailing: some View {
        HStack {
            Button {
                guard let url = global.root.directories.last,
                      let entry = FileEntry(url: url) else { return }
                global.root.newDocument(in: entry)
            } label: { Image(systemName: "doc.badge.plus") }
                .frame(size: .init(squared: 36))
            Button {
                guard let url = global.root.directories.last,
                      let entry = FileEntry(url: url) else { return }
                global.root.newDirectory(in: entry)
            } label: { Image(systemName: "folder.badge.plus") }
                .frame(size: .init(squared: 36))
            Button {
                global.root.toggleSelecting()
            } label: { Text(LocalizedStringKey(selector.isSelectingFiles ? "button_done" : "button_select")) }
        }
    }

    var bottomBar: some View {
        HStack {
            Button("Duplicate") {}
            Spacer()
            Button("Move") {}
            Spacer()
            Button("Delete") {
                global.root.moveToDeleted(at: .init(global.root.selectedFiles))
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
        DirectoryView(url: .deletedDirectory)
    }
}

struct FileRenameView: View {
    let entry: FileEntry

    @State private var name: String
    @State private var isValid: Bool = false

    init(entry: FileEntry) {
        self.entry = entry
        name = entry.url.name
    }

    var body: some View {
        content
            .onChange(of: name) {
                isValid = !entry.url.renaming(to: name, ext: "symbolic").exists
            }
    }
}

extension FileRenameView {
    @ViewBuilder var content: some View {
        TextField("New name", text: $name)
            .textInputAutocapitalization(.never)
        Button(LocalizedStringKey("button_cancel")) {}
        Button(LocalizedStringKey("button_done")) { global.root.rename(at: entry, name: name) }
            .disabled(!isValid)
    }
}

struct FileRenameAlertModifier: ViewModifier {
    let entry: FileEntry
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.alert("Rename \(entry.isDirectory ? "folder" : "document")", isPresented: $isPresented) {
            FileRenameView(entry: entry)
        }
    }
}
