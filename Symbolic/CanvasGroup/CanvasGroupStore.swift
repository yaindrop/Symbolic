import Foundation

struct CanvasGroup: Identifiable {
    enum Member {
        struct Path {
            let id: UUID
        }

        struct CanvasGroup {
            let id: UUID
        }

        case path(Path)
        case group(CanvasGroup)
    }

    let id: UUID
    let members: [Member]
}

typealias CanvasGroupMap = [UUID: CanvasGroup]

class CanvasGroupStore: Store {
    @Trackable var groupMap = CanvasGroupMap()
}
