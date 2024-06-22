import SwiftUI

struct RootView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(animation: .fast, { global.root.showCanvas }) var showCanvas
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
                SidebarView()
            } detail: {
                DocumentsView()
            }
            .if(selector.showCanvas) {
                $0.overlay {
                    CanvasView()
                        .background(.background)
                }
            }
        }
    }}
}

struct DocumentsView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var syncNotify: Bool { true }
        @Selected({ global.panel.movingPanelMap }) var movingPanelMap
    }

    @SelectorWrapper var selector

    @State private var fileTree: FileTree?

    var body: some View { trace {
        setupSelector {
            content
                .onAppear {
                    Task {
                        fileTree = await listFiles()
                    }
                }
        }
    } }
}

extension DocumentsView {
    var data: [FileTree.Entry] {
        guard let fileTree else { return [] }
        return fileTree.dirToEntries[fileTree.root] ?? []
    }

    var content: some View {
        ZStack {
            ScrollView {
                VStack {
                    Button("Canvas!") { global.root.update(showCanvas: !global.root.showCanvas) }
//                        .fullScreenCover(isPresented: $showCanvas) {
//                            CanvasView()
//                        }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                        ForEach(data, id: \.url) { entry in
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "questionmark.app.dashed")
                                        .font(.title)
                                }
                                .frame(maxWidth: .infinity, maxHeight: 100, alignment: .center)
                                .background(.background.tertiary)
                                Divider()
                                Text(entry.url.lastPathComponent)
                                    .frame(maxWidth: .infinity, maxHeight: 50, alignment: .center)
                                    .background(entry.isDirectory ? .blue : .gray)
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                            .frame(width: 150, height: 150, alignment: .center)
                            .clipRounded(radius: 12)
                            .onTapGesture {
                                global.root.open(url: entry.url)
                            }
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

struct FileTree {
    struct Entry {
        let url: URL
        let isDirectory: Bool
    }

    let root: URL
    let dirToEntries: [URL: [Entry]]
}

extension FileTree {
    init(root: URL) {
        var dirToEntries: [URL: [Entry]] = [:]
        let enumerator = FileManager.default.enumerator(atPath: root.path)
        while let relative = enumerator?.nextObject() as? String {
            let url = root.appending(path: relative)
            guard let fType = enumerator?.fileAttributes?[FileAttributeKey.type] as? FileAttributeType,
                  fType == .typeRegular || fType == .typeDirectory else { continue }
            let isDirectory = fType == .typeDirectory
            let parent = url.deletingLastPathComponent()
            var peers = dirToEntries.getOrSetDefault(key: parent, [])
            peers.append(.init(url: url, isDirectory: isDirectory))
            dirToEntries[parent] = peers
        }

        self.root = root
        self.dirToEntries = dirToEntries
    }
}

@MainActor
func listFiles() async -> FileTree? {
    let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    do {
        let foobarUrl = documentURL.appendingPathComponent("foobar.symbolic")

        let helloWorldString = "Hello, World!"
        if !FileManager.default.fileExists(atPath: foobarUrl.path) {
            FileManager.default.createFile(atPath: foobarUrl.path, contents: .init())
        }
        if let data = helloWorldString.data(using: .utf8) {
            let file = try FileHandle(forWritingTo: foobarUrl)
            try file.write(contentsOf: data)
        }

        let foobardirUrl = documentURL.appendingPathComponent("foobardir")
        try FileManager.default.createDirectory(at: foobardirUrl, withIntermediateDirectories: true)
        let foobar2Url = foobardirUrl.appendingPathComponent("foobar2.symbolicdoc")
        if let data = helloWorldString.data(using: .utf8) {
            do {
                try data.write(to: foobar2Url)
                print("Successfully wrote to file!")
            } catch {
                print("Error writing to file: \(error)")
            }
        }

        return FileTree(root: documentURL)
    } catch {
        print("Failed to list files: \(error)")
        return nil
    }
}
