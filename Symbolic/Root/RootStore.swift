import Foundation

private let subtracer = tracer.tagged("RootStore")

class RootStore: Store {
    @Trackable var fileTree: FileTree? = nil

    @Trackable var showCanvas = false
    @Trackable var activeDocumentUrl: URL?

    var savingTask: Task<Void, Never>?
}

private extension RootStore {
    func update(fileTree: FileTree) {
        update { $0(\._fileTree, fileTree) }
    }

    func update(showCanvas: Bool) {
        update { $0(\._showCanvas, showCanvas) }
    }

    func update(activeDocumentUrl: URL?) {
        update { $0(\._activeDocumentUrl, activeDocumentUrl) }
    }
}

extension RootStore {
    func loadFileTree(at url: URL) {
        Task { @MainActor in
            let _r = subtracer.range(type: .intent, "load file tree"); defer { _r() }
            guard let fileTree = FileTree(root: url) else { return }
            subtracer.instant("fileTree size=\(fileTree.directoryMap.count)")
            self.update(fileTree: fileTree)
        }
    }

    func loadDirectory(at url: URL) {
        Task { @MainActor in
            let _r = subtracer.range(type: .intent, "load directory \(url.lastPathComponent)"); defer { _r() }
            guard let directory = FileDirectory(url: url) else { return }
            subtracer.instant("directory size=\(directory.contents.count)")

            guard var fileTree = self.fileTree else { return }
            fileTree.directoryMap[directory.url] = directory
            self.update(fileTree: fileTree)
        }
    }

    func open(documentAt url: URL) {
        let _r = subtracer.range(type: .intent, "open document url=\(url)"); defer { _r() }
        guard let data = try? Data(contentsOf: url) else { return }
        subtracer.instant("data size=\(data.count)")

        let decoder = JSONDecoder()
        guard let document = try? decoder.decode(Document.self, from: data) else { return }
        subtracer.instant("document size=\(document.events.count)")

        withStoreUpdating {
            update(showCanvas: true)
            update(activeDocumentUrl: url)
            global.document.setDocument(document)
        }
    }

    func newDirectory(in entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "new directory in directory url=\(entry.url)"); defer { _r() }
        guard let _ = try? entry.newDirectory() else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
    }

    func newDocument(in entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "new document in directory url=\(entry.url)"); defer { _r() }
        let document = Document(from: fooSvg)
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(document),
              let newUrl = try? entry.newFile(ext: "symbolic", data: data) else { return }

        subtracer.instant("newUrl=\(newUrl)")

        withStoreUpdating {
            update(showCanvas: true)
            update(activeDocumentUrl: newUrl)
            global.document.setDocument(document)
            loadFileTree(at: .documentDirectory)
        }
    }

    func moveToDeleted(at entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "move to deleted at url=\(entry.url)"); defer { _r() }
        _ = move(at: entry, in: .deletedDirectory)
    }

    func delete(at entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "delete at url=\(entry.url)"); defer { _r() }
        guard let _ = try? entry.delete() else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
    }

    func wrapDirectory(at entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "wrap directory at url=\(entry.url)"); defer { _r() }
        guard let parent = entry.parent,
              let newUrl = try? parent.newDirectory(),
              let _ = try? entry.move(in: newUrl) else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
    }

    func unwrapDirectory(at entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "unwrap directory at url=\(entry.url)"); defer { _r() }
        guard let parent = entry.parent,
              let directory = FileDirectory(url: parent.url) else { return }
        for entry in directory.contents {
            _ = try? entry.move(in: parent.url)
        }
        guard let _ = try? entry.delete() else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
    }

    func move(at entry: FileEntry, in directoryUrl: URL) -> Bool {
        let _r = subtracer.range(type: .intent, "move at url=\(entry.url) in directoryUrl=\(directoryUrl)"); defer { _r() }
        guard let _ = try? entry.move(in: directoryUrl) else { return false }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
        return true
    }

    func rename(at entry: FileEntry, name: String) {
        let _r = subtracer.range(type: .intent, "rename at url=\(entry.url) with name=\(name)"); defer { _r() }
        guard let _ = try? entry.rename(name: name) else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
    }

    func save(document: Document) {
        let _r = subtracer.range(type: .intent, "save document"); defer { _r() }
        guard let activeDocumentUrl else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(document) else { return }
        subtracer.instant("data size=\(data.count)")

        do {
            try data.write(to: activeDocumentUrl)
        } catch {
            return
        }
    }

    func asyncSave(document: Document) {
        savingTask?.cancel()
        savingTask = Task { @MainActor in
            self.save(document: document)
        }
    }

    func exit() {
        withStoreUpdating {
            update(showCanvas: false)
            update(activeDocumentUrl: nil)
        }
    }
}

let fooSvg = """
<svg width="300" height="200" xmlns="http://www.w3.org/2000/svg">
  <!-- Define the complex path with different commands -->
  <path d="M 0 0 L 50 50 L 100 0 Z
           M 50 100
           C 60 110, 90 140, 100 150
           S 180 120, 150 100
           Q 160 180, 150 150
           T 200 150
           A 50 70 40 0 0 250 150
           Z" fill="none" stroke="black" stroke-width="2" />
</svg>
"""
