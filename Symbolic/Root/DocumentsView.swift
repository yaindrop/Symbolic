import SwiftUI

// MARK: - DocumentsView

struct DocumentsView: View, TracedView {
    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension DocumentsView {
    @ViewBuilder var content: some View {
        NavigationStack {
            DirectoryView(url: .documentDirectory)
        }
    }
}

// MARK: - DirectoryView

private struct DirectoryView: View, TracedView, SelectorHolder {
    @Environment(\.dismiss) private var dismiss

    let url: URL

    class Selector: SelectorBase {
        @Selected(animation: .fast, { global.root.fileTree }) var fileTree
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
                .onAppear {
                    global.root.load(directory: url)
                }
                .onDisappear {
                    print("dbf disappear", url)
                }
        }
    } }
}

// MARK: private

private extension DirectoryView {
    var directory: FileDirectory? { selector.fileTree?.directoryMap[url] }

    var entries: [FileEntry] {
        directory?.entries.sorted {
            $0.isDirectory != $1.isDirectory
                ? $0.isDirectory
                : $0.url.lastPathComponent < $1.url.lastPathComponent
        } ?? []
    }

    var content: some View {
        ScrollView {
            VStack {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                    ForEach(entries, id: \.url) {
                        EntryCard(entry: $0)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(url.lastPathComponent)
        .toolbar {
            Button { global.root.newDocument(inDirectory: url) } label: { Image(systemName: "doc.badge.plus") }
            Button { global.root.newDirectory(inDirectory: url) } label: { Image(systemName: "folder.badge.plus") }
            Button {} label: { Text("选择") }
        }
    }
}

// MARK: - EntryCard

struct EntryCard: View, TracedView {
    let entry: FileEntry

    @State private var showingDeleteFolderAlert = false

    var body: some View { trace {
        content
            .contextMenu { EntryCardMenu(entry: entry, showingDeleteFolderAlert: $showingDeleteFolderAlert) }
    } }
}

// MARK: private

private extension EntryCard {
    @ViewBuilder var content: some View {
        if entry.isDirectory {
            NavigationLink { DirectoryView(url: entry.url) } label: { card }
                .tint(.label)
                .dropDestination(for: URL.self) { payload, _ in
                    guard let url = payload.first else { return false }
                    return global.root.move(at: url, in: entry.url)
                }
        } else {
            Button { global.root.open(documentFrom: entry.url) } label: { card }
                .tint(.label)
        }
    }

    var card: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: entry.isDirectory ? "folder" : "doc")
                    .font(.system(size: 48))
                    .fontWeight(.light)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: 100, alignment: .center)
            .background(.background.tertiary)
            Divider()
            HStack {
                Text(entry.url.lastPathComponent)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: 54)
            .background(entry.isDirectory ? .blue : .gray)
            .foregroundColor(.white)
        }
        .frame(width: 150, height: 150, alignment: .center)
        .clipRounded(radius: 12)
        .shadow(radius: 6)
        .draggable(entry.url)
        .alert("Do you want to delete this folder with all contents?", isPresented: $showingDeleteFolderAlert) {
            Button("Cancel", role: .cancel) {}
            Button("OK", role: .destructive) { global.root.delete(at: entry.url) }
        }
    }
}

// MARK: - EntryCardMenu

struct EntryCardMenu: View {
    let entry: FileEntry

    @Binding var showingDeleteFolderAlert: Bool

    var body: some View {
        content
    }
}

// MARK: private

extension EntryCardMenu {
    @ViewBuilder var content: some View {
        Button("Properties", systemImage: "info.circle") {}
        Button("Rename", systemImage: "pencil") {}
        Button("Wrap in new folder", systemImage: "folder.badge.plus") {}
        Divider()
        Button("Copy", systemImage: "doc.on.doc") {}
        Button("Cut", systemImage: "scissors") {}
        Button("Duplicate", systemImage: "plus.square.on.square") {}
        Divider()
        if entry.isDirectory {
            Button("Unwrap folder", systemImage: "folder.badge.minus", role: .destructive) {}
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            if entry.isDirectory && FileDirectory(url: entry.url)?.entries.isEmpty == false {
                showingDeleteFolderAlert = true
            } else {
                global.root.delete(at: entry.url)
            }
        }
    }
}
