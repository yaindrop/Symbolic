import SwiftUI

// MARK: - FileEntryCard

struct FileEntryCard: View, TracedView, ComputedSelectorHolder {
    let entry: FileEntry

    struct SelectorProps: Equatable { let entry: FileEntry }
    class Selector: SelectorBase {
        @Selected({ global.fileBrowser.isSelectingFiles }) var isSelectingFiles
        @Selected(configs: .init(animation: .fast), { global.fileBrowser.selectedFiles.contains($0.entry) }) var selected
    }

    @SelectorWrapper var selector

    @State private var showingProperties = false
    @State private var showingRenameAlert = false

    var body: some View { trace("url=\(entry.url)") {
        setupSelector(.init(entry: entry)) {
            content
                .modifier(FileRenameAlertModifier(entry: entry, isPresented: $showingRenameAlert))
                .sheet(isPresented: $showingProperties) { propertiesSheet }
                .contextMenu {
                    EntryCardMenu(
                        entry: entry,
                        onProperties: { showingProperties = true },
                        onRename: { showingRenameAlert = true }
                    )
                }
        }
    } }
}

// MARK: private

private extension FileEntryCard {
    @ViewBuilder var content: some View {
        Button {
            if selector.isSelectingFiles {
                global.fileBrowser.toggleSelect(at: entry)
            } else {
                global.fileBrowser.open(at: entry)
            }
        } label: {
            card
        }
        .tint(.label)
        .overlay { selectingOverlay }
        .if(!selector.isSelectingFiles) {
            $0.draggable(entry.url)
                .if(entry.isDirectory) {
                    $0.dropDestination(for: URL.self) { payload, _ in
                        guard let payloadUrl = payload.first,
                              let payloadEntry = FileEntry(url: payloadUrl) else { return false }
                        return global.fileBrowser.move(at: payloadEntry, in: entry.url)
                    }
                }
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
            .foregroundStyle(.white)
        }
        .frame(width: 150, height: 150, alignment: .center)
        .clipRounded(radius: 12)
        .shadow(radius: 3)
    }

    @ViewBuilder var selectingOverlay: some View {
        if selector.isSelectingFiles {
            Image(systemName: selector.selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selector.selected ? .blue : .white)
                .font(.title3)
                .shadow(color: (selector.selected ? Color.systemBackground : .label).opacity(0.66), radius: 1)
                .padding(6)
                .innerAligned(.topLeading)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder var propertiesSheet: some View {
        VStack {
            HStack {
                Text("Name")
                Spacer()
                Text(entry.url.name)
            }
        }
        .padding()
    }
}

// MARK: - EntryCardMenu

private struct EntryCardMenu: View {
    let entry: FileEntry
    let onProperties: () -> Void
    let onRename: () -> Void

    var body: some View {
        content
    }
}

// MARK: private

extension EntryCardMenu {
    @ViewBuilder var content: some View {
        Button("Properties", systemImage: "info.circle") { onProperties() }
        Button("Rename", systemImage: "pencil") { onRename() }
        Button("Wrap in new folder", systemImage: "folder.badge.plus") { global.fileBrowser.wrapDirectory(at: entry) }
        Divider()
        Button("Copy", systemImage: "doc.on.doc") {}
        Button("Cut", systemImage: "scissors") {}
        Button("Duplicate", systemImage: "plus.square.on.square") {}
        Divider()
        if entry.isDirectory {
            Button("Unwrap folder", systemImage: "folder.badge.minus", role: .destructive) {
                global.fileBrowser.unwrapDirectory(at: entry)
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            global.fileBrowser.moveToDeleted(at: [entry])
        }
    }
}
