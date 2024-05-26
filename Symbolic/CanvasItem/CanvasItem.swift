import Foundation

struct CanvasItem: TriviallyCloneable {
    enum Kind {
        struct Path {
            let id: UUID
        }

        struct Group {
            let id: UUID
        }

        case path(Path)
        case group(Group)
    }

    let kind: Kind
    let zIndex: Double
}

extension CanvasItem: Identifiable {
    var id: UUID {
        switch kind {
        case let .path(path): path.id
        case let .group(group): group.id
        }
    }
}
