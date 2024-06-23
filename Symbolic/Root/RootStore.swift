import Foundation

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
    func loadFiles() {
        Task { @MainActor in
            if let fileTree = await FileTree.documentDirectory() {
                self.update(fileTree: fileTree)
            }
        }
    }

    func open(documentFrom url: URL) {
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: url) else { return }
        guard let document = try? decoder.decode(Document.self, from: data) else { return }

        withStoreUpdating {
            update(showCanvas: true)
            update(activeDocumentUrl: url)
            global.document.setDocument(document)
        }
    }

    func new(inDirectory url: URL) {
        let prefix = "Untitled"
        let ext = "symbolic"
        var index = 0
        var name: String { "\(prefix) \(index).\(ext)" }
        var newUrl: URL { url.appendingPathComponent(name) }

        let document = Document()
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(document) else { return }

        while FileManager.default.fileExists(atPath: newUrl.path) {
            index += 1
        }

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
        guard let activeDocumentUrl else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(document) else { return }

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
