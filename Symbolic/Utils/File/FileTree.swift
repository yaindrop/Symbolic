import Foundation

extension URL {
    func relativeTo(root: URL) -> String? {
        if path.hasPrefix(root.path) {
            return .init(path.dropFirst(root.path.count))
        }
        return nil
    }

    var relativeToDocument: String? {
        guard let relative = relativeTo(root: .documentDirectory) else { return nil }
        return "Documents/" + relative
    }

    static var documentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static var privateDirectory: URL {
        documentDirectory.appending(path: ".symbolic", directoryHint: .isDirectory)
    }

    static var deletedDirectory: URL {
        privateDirectory.appending(path: "deleted", directoryHint: .isDirectory)
    }

    var exists: Bool { FileManager.default.fileExists(atPath: path) }

    func create() throws { try FileManager.default.createDirectory(at: self, withIntermediateDirectories: true) }

    var name: String {
        guard !pathExtension.isEmpty else { return lastPathComponent }
        return .init(lastPathComponent.dropLast(pathExtension.count + 1))
    }

    func renaming(to name: String) -> URL {
        let ext = pathExtension.isEmpty ? nil : pathExtension
        var dotExt: String { if let ext { ".\(ext)" } else { "" }}
        var fullname: String { "\(name)\(dotExt)" }
        return deletingLastPathComponent().appending(path: fullname)
    }

    func renaming(to name: String, ext: String?) -> URL {
        var dotExt: String { if let ext { ".\(ext)" } else { "" }}
        var fullname: String { "\(name)\(dotExt)" }
        return deletingLastPathComponent().appending(path: fullname)
    }
}

// MARK: - FileEntry

struct FileEntry: Equatable, Hashable {
    let url: URL
    let isDirectory: Bool

    init?(url: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fType = attributes[FileAttributeKey.type] as? FileAttributeType,
              fType == .typeRegular || fType == .typeDirectory else { return nil }
        let isDirectory = fType == .typeDirectory
        self.url = url.deletingLastPathComponent().appending(path: url.lastPathComponent, directoryHint: isDirectory ? .isDirectory : .notDirectory)
        self.isDirectory = isDirectory
    }
}

extension FileEntry: CustomStringConvertible {
    var description: String {
        "FileEntry(url=\(url.relativeToDocument?.description ?? "nil"), isDirectory=\(isDirectory)"
    }
}

extension FileEntry {
    var parent: FileEntry? { FileEntry(url: url.deletingLastPathComponent()) }

    func newDirectory(name: String = "Untitled Folder") throws -> URL {
        var index = 0
        var fullname: String { index == 0 ? "\(name)" : "\(name) \(index)" }

        var newUrl: URL { url.appendingPathComponent(fullname) }
        while FileEntry(url: newUrl) != nil {
            index += 1
        }

        try FileManager.default.createDirectory(at: newUrl, withIntermediateDirectories: true)
        return newUrl
    }

    func newFile(name: String = "Untitled", ext: String? = nil, data: Data) throws -> URL {
        var index = 0
        var dotExt: String { if let ext { ".\(ext)" } else { "" }}
        var fullname: String { index == 0 ? "\(name)\(dotExt)" : "\(name) \(index)\(dotExt)" }

        var newUrl: URL { url.appendingPathComponent(fullname) }
        while FileEntry(url: newUrl) != nil {
            index += 1
        }

        try data.write(to: newUrl)
        return newUrl
    }

    func delete() throws -> URL {
        try FileManager.default.removeItem(at: url)
        return url.deletingLastPathComponent()
    }

    func move(in directoryUrl: URL) throws -> URL {
        let newUrl = directoryUrl.appending(path: url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: newUrl)
        return newUrl
    }

    func rename(name: String) throws -> URL {
        let newUrl = url.renaming(to: name)
        try FileManager.default.moveItem(at: url, to: newUrl)
        return newUrl
    }

    func rename(name: String, ext: String?) throws -> URL {
        let newUrl = url.renaming(to: name, ext: ext)
        try FileManager.default.moveItem(at: url, to: newUrl)
        return newUrl
    }
}

// MARK: - FileDirectory

struct FileDirectory: Equatable {
    let entry: FileEntry
    var contents: [FileEntry]
}

extension FileDirectory {
    var url: URL { entry.url }

    init?(url: URL) {
        guard let entry = FileEntry(url: url),
              let contentNames = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return nil }
        let contents: [FileEntry] = contentNames.compactMap { name in
            guard let entry = FileEntry(url: url.appending(path: name)),
                  !entry.url.lastPathComponent.hasPrefix(".") else { return nil }
            return entry
        }

        self.entry = entry
        self.contents = contents
    }
}

// MARK: - FileTree

struct FileTree: Equatable {
    let root: URL
    var directoryMap: [URL: FileDirectory]
}

extension FileTree {
    init?(root: URL) {
        guard let rootDirectory = FileDirectory(url: root) else { return nil }
        var directoryMap: [URL: FileDirectory] = [root: rootDirectory]
        let enumerator = FileManager.default.enumerator(atPath: root.path)
        while let relative = enumerator?.nextObject() as? String {
            guard let entry = FileEntry(url: root.appending(path: relative)),
                  !entry.url.lastPathComponent.hasPrefix(".") else { continue }
            if entry.isDirectory {
                directoryMap[entry.url] = FileDirectory(url: entry.url)
            }
        }

        guard directoryMap[root] != nil else { return nil }
        self.root = root
        self.directoryMap = directoryMap
    }
}
