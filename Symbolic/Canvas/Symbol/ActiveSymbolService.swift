import SwiftUI

private let subtracer = tracer.tagged("ActiveSymbolService")

// MARK: - ActiveSymbolStore

enum ActiveSymbolState: Equatable {
    case none
    case focused(UUID)
    case editing(UUID)

    var focusedSymbolId: UUID? { if case let .focused(id) = self { id } else { nil } }

    var editingSymbolId: UUID? { if case let .editing(id) = self { id } else { nil } }
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

    var focusedSymbolId: UUID? { state.focusedSymbolId }

    var editingSymbolId: UUID? { state.editingSymbolId }

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
