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
    func loadFileTree() {
        Task { @MainActor in
            let _r = subtracer.range(type: .intent, "load file tree"); defer { _r() }
            guard let fileTree = FileTree(root: .documentDirectory) else { return }
            subtracer.instant("fileTree size=\(fileTree.directoryMap.count)")
            self.update(fileTree: fileTree)
        }
    }

    func load(directory url: URL) {
        Task { @MainActor in
            let _r = subtracer.range(type: .intent, "load directory \(url.lastPathComponent)"); defer { _r() }
            guard let directory = FileDirectory(url: url) else { return }
            subtracer.instant("directory size=\(directory.entries.count)")

            guard var fileTree = self.fileTree else { return }
            fileTree.directoryMap[directory.url] = directory
            self.update(fileTree: fileTree)
        }
    }

    func open(documentFrom url: URL) {
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

    func newDirectory(inDirectory url: URL) {
        let _r = subtracer.range(type: .intent, "new directory in directory url=\(url)"); defer { _r() }
        let prefix = "Untitled Folder"
        var index = 0
        var name: String { index == 0 ? "\(prefix)" : "\(prefix) \(index)" }
        var newUrl: URL { url.appendingPathComponent(name) }

        while FileManager.default.fileExists(atPath: newUrl.path) {
            index += 1
        }

        try? FileManager.default.createDirectory(at: newUrl, withIntermediateDirectories: true)
        withStoreUpdating {
            loadFileTree()
        }
    }

    func newDocument(inDirectory url: URL) {
        let _r = subtracer.range(type: .intent, "new document in directory url=\(url)"); defer { _r() }
        let prefix = "Untitled"
        let ext = "symbolic"
        var index = 0
        var name: String { index == 0 ? "\(prefix).\(ext)" : "\(prefix) \(index).\(ext)" }
        var newUrl: URL { url.appendingPathComponent(name) }

        let document = Document(from: fooSvg)
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(document) else { return }
        subtracer.instant("data size=\(data.count)")

        while FileManager.default.fileExists(atPath: newUrl.path) {
            index += 1
        }

        subtracer.instant("name=\(name)")

        try? data.write(to: newUrl)

        withStoreUpdating {
            update(showCanvas: true)
            update(activeDocumentUrl: newUrl)
            global.document.setDocument(document)
            loadFileTree()
        }
    }

    func delete(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        withStoreUpdating {
            loadFileTree()
        }
    }

    func move(at url: URL, in directoryUrl: URL) -> Bool {
        do {
            try FileManager.default.moveItem(at: url, to: directoryUrl.appending(path: url.lastPathComponent))
            withStoreUpdating {
                loadFileTree()
            }
            return true
        } catch {
            return false
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
