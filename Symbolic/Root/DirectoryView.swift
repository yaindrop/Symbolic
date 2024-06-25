import SwiftUI

// MARK: - DirectoryView

struct DirectoryView: View, TracedView, SelectorHolder {
    @Environment(\.dismiss) private var dismiss

    @Binding var path: [URL]
    let url: URL

    class Selector: SelectorBase {
        @Selected(animation: .fast, { global.root.fileTree }) var fileTree
        @Selected({ global.root.isSelectingFiles }) var isSelectingFiles
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
                .onAppear {
                    global.root.loadDirectory(at: url)
                }
        }
    } }
}

// MARK: private

private extension DirectoryView {
    var directory: FileDirectory? { selector.fileTree?.directoryMap[url] }

    var entries: [FileEntry] {
        directory?.contents.sorted {
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
                        EntryCard(path: $path, entry: $0)
                    }
                }
            }
            .padding()
        }
        .overlay {
            if entries.isEmpty {
                Text("Folder is empty")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(url.lastPathComponent)
        .toolbar {
            Button {
                guard let directory else { return }
                global.root.newDocument(in: directory.entry)
            } label: { Image(systemName: "doc.badge.plus") }
            Button {
                guard let directory else { return }
                global.root.newDirectory(in: directory.entry)
            } label: { Image(systemName: "folder.badge.plus") }
            Button {
                global.root.toggleSelecting()
            } label: { Text(LocalizedStringKey(selector.isSelectingFiles ? "button_done" : "button_select")) }
        }
    }
}

// MARK: - EntryCard

struct EntryCard: View, TracedView, ComputedSelectorHolder {
    @Binding var path: [URL]
    let entry: FileEntry

    struct SelectorProps: Equatable { let entry: FileEntry }
    class Selector: SelectorBase {
        @Selected({ global.root.isSelectingFiles }) var isSelectingFiles
        @Selected(animation: .fast, { global.root.selectedFiles.contains($0.entry.url) }) var selected
    }

    @SelectorWrapper var selector

    @State private var showingRenameAlert = false

    var body: some View { trace {
        setupSelector(.init(entry: entry)) {
            content
                .contextMenu {
                    EntryCardMenu(
                        entry: entry,
                        onRename: { showingRenameAlert = true }
                    )
                }
        }
    } }
}

// MARK: private

private extension EntryCard {
    @ViewBuilder var content: some View {
        if selector.isSelectingFiles {
            card.onTapGesture {
                global.root.toggleSelect(at: entry.url)
            }
        } else if entry.isDirectory {
            Button { path.append(entry.url) } label: { card }
                .tint(.label)
                .dropDestination(for: URL.self) { payload, _ in
                    guard let payloadUrl = payload.first,
                          let payloadEntry = FileEntry(url: payloadUrl) else { return false }
                    return global.root.move(at: payloadEntry, in: entry.url)
                }
        } else {
            Button { global.root.open(documentAt: entry.url) } label: { card }
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
                Text(entry.url.name)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: 54)
            .background(entry.isDirectory ? .blue : .gray)
            .foregroundColor(.white)
        }
        .frame(width: 150, height: 150, alignment: .center)
        .clipRounded(radius: 12)
        .shadow(radius: 3)
        .draggable(entry.url)
        .modifier(FileRenameAlertModifier(entry: entry, isPresented: $showingRenameAlert))
        .overlay {
            if selector.isSelectingFiles {
                Image(systemName: selector.selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selector.selected ? .blue : .white)
                    .font(.title3)
                    .shadow(color: (selector.selected ? Color.systemBackground : .label).opacity(0.66), radius: 1)
                    .padding(6)
                    .innerAligned(.topLeading)
            }
        }
    }
}

// MARK: - EntryCardMenu

struct EntryCardMenu: View {
    let entry: FileEntry
    let onRename: () -> Void

    var body: some View {
        content
    }
}

// MARK: private

extension EntryCardMenu {
    @ViewBuilder var content: some View {
        Button("Properties", systemImage: "info.circle") {}
        Button("Rename", systemImage: "pencil") { onRename() }
        Button("Wrap in new folder", systemImage: "folder.badge.plus") { global.root.wrapDirectory(at: entry) }
        Divider()
        Button("Copy", systemImage: "doc.on.doc") {}
        Button("Cut", systemImage: "scissors") {}
        Button("Duplicate", systemImage: "plus.square.on.square") {}
        Divider()
        if entry.isDirectory {
            Button("Unwrap folder", systemImage: "folder.badge.minus", role: .destructive) {
                global.root.unwrapDirectory(at: entry)
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            global.root.moveToDeleted(at: entry)
        }
    }
}
