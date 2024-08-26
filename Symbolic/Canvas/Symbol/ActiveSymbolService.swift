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

    var focusedSymbolId: UUID? { if case let .focused(id) = state { id } else { nil } }

    var editingSymbolId: UUID? { if case let .editing(id) = state { id } else { nil } }

    var unfocusedSymbolIds: [UUID] { symbol.symbolIds.filter { $0 != focusedSymbolId }}
}

extension ActiveSymbolService {
    func setFocus(symbolId: UUID?) {
        if let symbolId {
            store.update(state: .focused(symbolId))
        } else {
            store.update(state: .none)
        }
    }
}
