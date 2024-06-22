import Foundation

struct ItemGroup: Identifiable, Equatable, Codable {
    let id: UUID
    let members: [UUID]
}

extension ItemGroup: CustomStringConvertible {
    var description: String {
        "Group(id: \(id), members: \(members))"
    }
}

struct Item: TriviallyCloneable, Equatable, Codable {
    enum Kind: Equatable, Codable {
        case path(UUID)
        case group(ItemGroup)
    }

    let kind: Kind
}

extension Item {
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

extension Item: CustomStringConvertible {
    var description: String {
        switch kind {
        case let .path(id): "Item(pathId: \(id))"
        case let .group(group): "Item(group: \(group))"
        }
    }
}
