import Foundation

extension URL {
    static var documentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

// MARK: - FileEntry

struct FileEntry: Equatable {
    let url: URL
    let isDirectory: Bool
}

// MARK: - FileDirectory

struct FileDirectory: Equatable {
    let url: URL
    var entries: [FileEntry]
}

extension FileDirectory {
    init?(url: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return nil }
        let entries: [FileEntry] = contents.compactMap { name in
            guard !name.hasPrefix("."),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: url.appending(path: name).path),
                  let fType = attributes[FileAttributeKey.type] as? FileAttributeType,
                  fType == .typeRegular || fType == .typeDirectory else { return nil }
            let entryUrl = url.appending(path: name, directoryHint: fType == .typeDirectory ? .isDirectory : .notDirectory)
            return FileEntry(url: entryUrl, isDirectory: fType == .typeDirectory)
        }

        self.url = url
        self.entries = entries
    }
}

// MARK: - FileTree

struct FileTree: Equatable {
    let root: URL
    var directoryMap: [URL: FileDirectory]
}

extension FileTree {
    init?(root: URL) {
        var directoryMap: [URL: FileDirectory] = [:]
        let enumerator = FileManager.default.enumerator(atPath: root.path)
        while let relative = enumerator?.nextObject() as? String {
            guard let fType = enumerator?.fileAttributes?[FileAttributeKey.type] as? FileAttributeType,
                  fType == .typeRegular || fType == .typeDirectory else { continue }
            let entryUrl = root.appending(path: relative, directoryHint: fType == .typeDirectory ? .isDirectory : .notDirectory)

            let name = entryUrl.lastPathComponent
            guard !name.hasPrefix(".") else { continue }

            let directoryUrl = entryUrl.deletingLastPathComponent()
            var directory = directoryMap.getOrSetDefault(key: directoryUrl, .init(url: directoryUrl, entries: []))
            directory.entries.append(.init(url: entryUrl, isDirectory: fType == .typeDirectory))
            directoryMap[directoryUrl] = directory
        }

        guard directoryMap[root] != nil else { return nil }
        self.root = root
        self.directoryMap = directoryMap
    }
}
