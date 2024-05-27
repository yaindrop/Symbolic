import Foundation

struct ItemGroup {
    let id: UUID
    let members: [UUID]
}

struct Item: TriviallyCloneable {
    enum Kind {
        case path(UUID)
        case group(ItemGroup)
    }

    let kind: Kind
}

extension Item: Identifiable {
    var id: UUID {
        switch kind {
        case let .path(id): id
        case let .group(group): group.id
        }
    }
}
