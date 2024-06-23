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
            guard let fileTree = FileTree.documentDirectory else { return }
            subtracer.instant("fileTree size=\(fileTree.dirToEntries.count)")
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

    func new(inDirectory url: URL) {
        let _r = subtracer.range(type: .intent, "new in directory url=\(url)"); defer { _r() }
        let prefix = "Untitled"
        let ext = "symbolic"
        var index = 0
        var name: String { index == 0 ? "\(prefix).\(ext)" : "\(prefix) \(index).\(ext)" }
        var newUrl: URL { url.appendingPathComponent(name) }

        let document = Document()
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(document) else { return }
        subtracer.instant("data size=\(data.count)")

        while FileManager.default.fileExists(atPath: newUrl.path) {
            index += 1
        }

        subtracer.instant("name=\(name)")

        do {
            try data.write(to: newUrl)
        } catch {
            return
        }

        withStoreUpdating {
            update(showCanvas: true)
            update(activeDocumentUrl: newUrl)
            global.document.setDocument(document)
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
