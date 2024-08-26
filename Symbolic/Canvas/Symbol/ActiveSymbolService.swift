import SwiftUI

private let subtracer = tracer.tagged("ActiveSymbolService")

// MARK: - ActiveSymbolStore

enum ActiveSymbolState: Equatable {
    case none
    case active(Set<UUID>)
    case focused(UUID)
    case editing(UUID)
}

class ActiveSymbolStore: Store {
    @Trackable var state: ActiveSymbolState = .none
}

private extension ActiveSymbolStore {
    func update(state: ActiveSymbolState) {
        withStoreUpdating(configs: .init(animation: .faster)) {
            update { $0(\._state, state) }
        }
    }
}

// MARK: - ActiveSymbolService

struct ActiveSymbolService {
    let store: ActiveSymbolStore
    let symbol: SymbolService
}

// MARK: selectors

extension ActiveSymbolService {
    var state: ActiveSymbolState { store.state }

    var activeSymbolIds: Set<UUID> {
        switch state {
        case .none: []
        case let .active(ids): ids
        case let .focused(id): [id]
        case let .editing(id): [id]
        }
    }

    var focusedSymbolId: UUID? {
        switch state {
        case let .focused(id): id
        case let .editing(id): id
        default: nil
        }
    }

    var editingSymbolId: UUID? { if case let .editing(id) = state { id } else { nil } }

    var focusedSymbol: Symbol? { focusedSymbolId.map { symbol.get(id: $0) } }

    var symbolToWorld: CGAffineTransform { focusedSymbol?.symbolToWorld ?? .identity }

    var worldToSymbol: CGAffineTransform { focusedSymbol?.worldToSymbol ?? .identity }

    var selectedSymbolIds: Set<UUID> {
        switch state {
        case let .active(ids): ids
        default: []
        }
    }

    func selected(id: UUID) -> Bool {
        selectedSymbolIds.contains(id)
    }
}

extension ActiveSymbolService {
    func setFocus(symbolId: UUID?) {
        if let symbolId {
            store.update(state: .focused(symbolId))
        } else {
            store.update(state: .none)
        }
    }

    func setEditing(symbolId: UUID?) {
        if let symbolId {
            store.update(state: .editing(symbolId))
        } else {
            store.update(state: .none)
        }
    }
}
