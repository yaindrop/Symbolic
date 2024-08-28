import Foundation

// MARK: - Item

struct Item: TriviallyCloneable, Equatable, Codable {
    struct Path: Identifiable, Equatable, Codable {
        let id: UUID
    }

    struct Group: Identifiable, Equatable, Codable {
        let id: UUID
        var members: [UUID]
    }

    struct Symbol: Identifiable, Equatable, Codable {
        let id: UUID
        var members: [UUID]
    }

    enum Kind: Equatable, Codable {
        case path(Path)
        case group(Group)
        case symbol(Symbol)
    }

    let kind: Kind
}

extension Item {
    var path: Path? {
        if case let .path(item) = kind { item } else { nil }
    }

    var group: Group? {
        if case let .group(item) = kind { item } else { nil }
    }

    var symbol: Symbol? {
        if case let .symbol(item) = kind { item } else { nil }
    }
}

extension Item: Identifiable {
    var id: UUID {
        switch kind {
        case let .path(item): item.id
        case let .group(item): item.id
        case let .symbol(item): item.id
        }
    }
}

extension Item: CustomStringConvertible {
    var description: String {
        switch kind {
        case let .path(kind): "Item.Path(id: \(kind.id))"
        case let .group(kind): "Item.Group(id: \(kind.id), members: \(kind.members))"
        case let .symbol(kind): "Item.Symbol(id: \(kind.id), members: \(kind.members))"
        }
    }
}
