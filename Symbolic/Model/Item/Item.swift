import Foundation

struct ItemGroup: Identifiable {
    let id: UUID
    let members: [UUID]
}

struct Item: TriviallyCloneable {
    enum Kind {
        case path(UUID)
        case group(ItemGroup)
    }

    let kind: Kind

    var group: ItemGroup? {
        if case let .group(group) = kind { group } else { nil }
    }

    var pathId: UUID? {
        if case let .path(id) = kind { id } else { nil }
    }
}

extension Item: Identifiable {
    var id: UUID {
        switch kind {
        case let .path(id): id
        case let .group(group): group.id
        }
    }
}
