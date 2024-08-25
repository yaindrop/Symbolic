import SwiftUI

private let subtracer = tracer.tagged("ActiveSymbolService")

// MARK: - ActiveSymbolStore

class ActiveSymbolStore: Store {
    @Trackable var focusedSymbolId: UUID?
}

private extension ActiveSymbolStore {
    func update(focusedSymbolId: UUID?) {
        withStoreUpdating(configs: .init(animation: .faster)) {
            update { $0(\._focusedSymbolId, focusedSymbolId) }
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
    var focusedSymbolId: UUID? { store.focusedSymbolId }

    var unfocusedSymbolIds: [UUID] { symbol.symbolIds.filter { $0 != focusedSymbolId }}
}
