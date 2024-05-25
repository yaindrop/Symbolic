import Foundation

struct CanvasItem {
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

typealias CanvasItemMap = OrderedMap<UUID, CanvasItem>

class CanvasItemStore: Store {
    @Trackable var itemMap = CanvasItemMap()
}
