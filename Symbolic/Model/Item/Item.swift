import Foundation

// MARK: - ItemPath

struct ItemPath: Identifiable, Equatable, Codable {
    let id: UUID
}

extension ItemPath: CustomStringConvertible {
    var description: String {
        "Path(id: \(id))"
    }
}

// MARK: - ItemGroup

struct ItemGroup: Identifiable, Equatable, Codable {
    let id: UUID
    var members: [UUID]
}

extension ItemGroup {
    var event: ItemEvent.SetGroup {
        .init(groupId: id, members: members)
    }
}

extension ItemGroup: CustomStringConvertible {
    var description: String {
        "Group(id: \(id), members: \(members))"
    }
}

// MARK: - ItemSymbol

struct ItemSymbol: Identifiable, Equatable, Codable, TriviallyCloneable {
    let id: UUID
    var origin: Point2
    var size: CGSize
    var members: [UUID]
}

extension ItemSymbol {
    var event: ItemEvent.SetSymbol {
        .init(symbolId: id, origin: origin, size: size, members: members)
    }

    var boundingRect: CGRect {
        .init(origin: origin, size: size)
    }

    var symbolToWorld: CGAffineTransform {
        .init(translation: .init(origin))
    }

    var worldToSymbol: CGAffineTransform {
        symbolToWorld.inverted()
    }
}

extension ItemSymbol: CustomStringConvertible {
    var description: String {
        "Symbol(id: \(id.shortDescription), origin: \(origin), size: \(size))"
    }
}

// MARK: - Item

struct Item: TriviallyCloneable, Equatable, Codable {
    enum Kind: Equatable, Codable {
        case path(ItemPath)
        case group(ItemGroup)
        case symbol(ItemSymbol)
    }

    let kind: Kind
}

extension Item {
    var path: ItemPath? {
        if case let .path(item) = kind { item } else { nil }
    }

    var group: ItemGroup? {
        if case let .group(item) = kind { item } else { nil }
    }

    var symbol: ItemSymbol? {
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
        case let .path(kind): "Item(\(kind))"
        case let .group(kind): "Item(\(kind))"
        case let .symbol(kind): "Item(\(kind))"
        }
    }
}
