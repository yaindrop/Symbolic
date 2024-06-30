import SwiftUI

// MARK: - FileDirectoryView

struct FileDirectoryView: View, TracedView, SelectorHolder {
    let entry: FileEntry

    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .fast), { global.fileBrowser.fileTree }) var fileTree
        @Selected(configs: .init(animation: .fast), { global.fileBrowser.directoryPath }) var directoryPath
        @Selected({ global.fileBrowser.isSelectingFiles }) var isSelectingFiles
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
                .onAppear {
                    global.fileBrowser.loadDirectory(at: entry.url)
                }
        }
    } }
}

// MARK: private

private extension FileDirectoryView {
    var directory: FileDirectory? { selector.fileTree?.directoryMap[entry.url] }

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
                        FileEntryCard(entry: $0)
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
        .background(.background)
    }
}
