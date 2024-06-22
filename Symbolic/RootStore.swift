import Foundation

class RootStore: Store {
    @Trackable var fileTree: FileTree? = nil

    @Trackable var showCanvas = false
    @Trackable var activeDocumentUrl: URL?
}

extension RootStore {
    func update(fileTree: FileTree) {
        update { $0(\._fileTree, fileTree) }
    }

    func update(showCanvas: Bool) {
        update { $0(\._showCanvas, showCanvas) }
    }

    func open(url: URL) {
        let decoder = JSONDecoder()
        do {
            let data = try Data(contentsOf: url)
            let document = try decoder.decode(Document.self, from: data)
            print("open document success", document)
        } catch {
            print("open document error", error.localizedDescription)
        }
    }
}
