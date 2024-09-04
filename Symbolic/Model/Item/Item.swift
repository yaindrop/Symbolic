import Foundation

// MARK: - Item

struct Item: TriviallyCloneable, Equatable {
    struct Path: Identifiable, Equatable {
        let id: UUID
    }

    struct Group: Identifiable, Equatable {
        let id: UUID
        var members: [UUID]
    }

    struct Symbol: Identifiable, Equatable {
        let id: UUID
        var members: [UUID]
    }

    enum Kind: Equatable {
        case path(Path)
        case group(Group)
        case symbol(Symbol)
    }

    var name: String?
    var locked: Bool = false

    var kind: Kind
}

extension Item {
    var path: Path? {
        get { if case let .path(item) = kind { item } else { nil }}
        set { newValue.map { kind = .path($0) } }
    }

    var group: Group? {
        get { if case let .group(item) = kind { item } else { nil }}
        set { newValue.map { kind = .group($0) } }
    }

    var symbol: Symbol? {
        get { if case let .symbol(item) = kind { item } else { nil }}
        set { newValue.map { kind = .symbol($0) } }
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

extension Item {
    mutating func update(_ event: ItemEvent.SetName) {
        let _r = tracer.range("Item set name"); defer { _r() }
        name = event.name
    }

    mutating func update(_ event: ItemEvent.SetLocked) {
        let _r = tracer.range("Item set locked"); defer { _r() }
        locked = event.locked
    }
}
