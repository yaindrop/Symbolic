import Foundation

struct CanvasItemGroup {
    let id: UUID
    let members: [UUID]
}

struct CanvasItem: TriviallyCloneable {
    enum Kind {
        case path(UUID)
        case group(CanvasItemGroup)
    }

    let kind: Kind
}

extension CanvasItem: Identifiable {
    var id: UUID {
        switch kind {
        case let .path(id): id
        case let .group(group): group.id
        }
    }
}
