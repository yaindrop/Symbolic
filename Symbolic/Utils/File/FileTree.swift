import Foundation

struct FileTree: Equatable {
    struct Entry: Equatable {
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
            guard let fType = enumerator?.fileAttributes?[FileAttributeKey.type] as? FileAttributeType,
                  fType == .typeRegular || fType == .typeDirectory else { continue }
            let isDirectory = fType == .typeDirectory
            let url = root.appending(path: relative, directoryHint: isDirectory ? .isDirectory : .notDirectory)
            let name = url.lastPathComponent
            if name.hasPrefix(".") {
                continue
            }

            let parent = url.deletingLastPathComponent()
            var peers = dirToEntries.getOrSetDefault(key: parent, [])
            peers.append(.init(url: url, isDirectory: isDirectory))
            dirToEntries[parent] = peers
        }

        self.root = root
        self.dirToEntries = dirToEntries
    }

    @MainActor
    static func documentDirectory() async -> FileTree? {
        let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return FileTree(root: documentURL)
    }
}
