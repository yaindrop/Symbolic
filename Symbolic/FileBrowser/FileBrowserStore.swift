import Foundation

private let subtracer = tracer.tagged("FileBrowserStore")

// MARK: - FileBrowserStore

class FileBrowserStore: Store {
    @Trackable var fileTree: FileTree? = nil
    @Trackable var directoryPath: [FileEntry] = []
    @Trackable var forwardPath: [FileEntry] = []

    @Trackable var isSelectingFiles: Bool = false
    @Trackable var selectedFiles = Set<FileEntry>()

    @Trackable var activeDocument: FileEntry?

    var savingTask: Task<Void, Never>?
}

private extension FileBrowserStore {
    func update(fileTree: FileTree) {
        update { $0(\._fileTree, fileTree) }
    }

    func update(directoryPath: [FileEntry]) {
        update { $0(\._directoryPath, directoryPath) }
    }

    func update(forwardPath: [FileEntry]) {
        update { $0(\._forwardPath, forwardPath) }
    }
}

private extension FileBrowserStore {
    func update(isSelectingFiles: Bool) {
        update { $0(\._isSelectingFiles, isSelectingFiles) }
    }

    func update(selectedFiles: Set<FileEntry>) {
        update { $0(\._selectedFiles, selectedFiles) }
    }
}

private extension FileBrowserStore {
    func update(activeDocument: FileEntry?) {
        update { $0(\._activeDocument, activeDocument) }
    }
}

// MARK: selectors

extension FileBrowserStore {
    var directories: [FileEntry] { [.init(url: .documentDirectory)!] + directoryPath }
}

// MARK: actions

extension FileBrowserStore {
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
}

extension FileBrowserStore {
    func open(at entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "open \(entry)"); defer { _r() }
        if entry.isDirectory {
            withStoreUpdating {
                update(directoryPath: directoryPath.cloned { $0.append(entry) })
                update(forwardPath: [])
            }
        } else {
            guard let data = try? Data(contentsOf: entry.url) else { return }
            subtracer.instant("data size=\(data.count)")

            let decoder = JSONDecoder()
            guard let document = try? decoder.decode(Document.self, from: data) else { return }
            subtracer.instant("document size=\(document.events.count)")

            withStoreUpdating {
                update(activeDocument: .init(url: entry.url))
                global.document.setDocument(document)
            }
        }
    }

    func directoryBack() {
        let _r = subtracer.range(type: .intent, "directory back"); defer { _r() }
        var directoryPath = directoryPath
        guard let backed = directoryPath.popLast() else { return }
        withStoreUpdating {
            update(directoryPath: directoryPath)
            update(forwardPath: forwardPath.cloned { $0.insert(backed, at: 0) })
        }
    }

    func directoryForward() {
        let _r = subtracer.range(type: .intent, "directory forward"); defer { _r() }
        var forwardPath = forwardPath
        guard !forwardPath.isEmpty else { return }
        let forwarded = forwardPath.remove(at: 0)
        withStoreUpdating {
            update(directoryPath: directoryPath.cloned { $0.append(forwarded) })
            update(forwardPath: forwardPath)
        }
    }
}

extension FileBrowserStore {
    func newDirectory(in entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "new directory in directory \(entry)"); defer { _r() }
        guard let _ = try? entry.newDirectory() else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
    }

    func newDocument(in entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "new document in directory \(entry)"); defer { _r() }
        let document = Document(from: fooSvg)
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(document),
              let newUrl = try? entry.newFile(ext: "symbolic", data: data) else { return }

        subtracer.instant("newUrl=\(newUrl)")

        withStoreUpdating {
            update(activeDocument: .init(url: newUrl))
            global.document.setDocument(document)
            loadFileTree(at: .documentDirectory)
        }
    }
}

extension FileBrowserStore {
    func moveToDeleted(at entries: [FileEntry]) {
        let _r = subtracer.range(type: .intent, "move to deleted, at entries=\(entries)"); defer { _r() }
        for entry in entries {
            _ = try? entry.move(in: .deletedDirectory)
        }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
            if entries.contains(where: { $0 == activeDocument }) {
                update(activeDocument: nil)
            }
        }
    }

    func delete(at entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "delete at \(entry)"); defer { _r() }
        guard let _ = try? entry.delete() else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
    }

    func wrapDirectory(at entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "wrap directory at \(entry)"); defer { _r() }
        guard let parent = entry.parent,
              let newUrl = try? parent.newDirectory(),
              let _ = try? entry.move(in: newUrl) else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
    }

    func unwrapDirectory(at entry: FileEntry) {
        let _r = subtracer.range(type: .intent, "unwrap directory at \(entry)"); defer { _r() }
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
        let _r = subtracer.range(type: .intent, "move at \(entry) in directoryUrl=\(directoryUrl)"); defer { _r() }
        guard let _ = try? entry.move(in: directoryUrl) else { return false }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
        }
        return true
    }

    func rename(at entry: FileEntry, name: String) {
        let _r = subtracer.range(type: .intent, "rename at \(entry) with name=\(name)"); defer { _r() }
        guard let newUrl = try? entry.rename(name: name) else { return }
        withStoreUpdating {
            loadFileTree(at: .documentDirectory)
            if entry == activeDocument {
                update(activeDocument: .init(url: newUrl))
            }
        }
    }
}

extension FileBrowserStore {
    func save(document: Document) {
        let _r = subtracer.range(type: .intent, "save document"); defer { _r() }
        guard let activeDocument else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(document) else { return }
        subtracer.instant("data size=\(data.count)")

        do {
            try data.write(to: activeDocument.url)
        } catch {
            return
        }
    }

    func asyncSave(document: Document) {
        savingTask?.cancel()
        savingTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            self.save(document: document)
        }
    }

    func exit() {
        withStoreUpdating {
            update(activeDocument: nil)
        }
    }
}

extension FileBrowserStore {
    func toggleSelecting() {
        withStoreUpdating {
            if isSelectingFiles {
                update(isSelectingFiles: false)
                update(selectedFiles: .init())
            } else {
                update(isSelectingFiles: true)
                update(selectedFiles: .init())
            }
        }
    }

    func toggleSelect(at entry: FileEntry) {
        guard isSelectingFiles else { return }
        withStoreUpdating {
            if selectedFiles.contains(entry) {
                update(selectedFiles: selectedFiles.cloned { $0.remove(entry) })
            } else {
                update(selectedFiles: selectedFiles.cloned { $0.insert(entry) })
            }
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
