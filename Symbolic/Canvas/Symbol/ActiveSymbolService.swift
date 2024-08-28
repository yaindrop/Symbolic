import SwiftUI

private let subtracer = tracer.tagged("ActiveSymbolService")

// MARK: - ActiveSymbolStore

enum SymbolActiveState: Equatable {
    case none
    case active(Set<UUID>)
    case focused(UUID)
    case editing(UUID)
}

class ActiveSymbolStore: Store {
    @Trackable var state: SymbolActiveState = .none
}

private extension ActiveSymbolStore {
    func update(state: SymbolActiveState) {
        withStoreUpdating(configs: .init(animation: .faster)) {
            update { $0(\._state, state) }
        }
    }
}

// MARK: - ActiveSymbolService

struct ActiveSymbolService {
    let store: ActiveSymbolStore
    let path: PathService
    let symbol: SymbolService
    let item: ItemService
    let viewport: ViewportService
}

// MARK: selectors

extension ActiveSymbolService {
    var state: SymbolActiveState { store.state }

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

    var editingSymbol: Symbol? { editingSymbolId.map { symbol.get(id: $0) } }

    var symbolToWorld: CGAffineTransform { focusedSymbol?.symbolToWorld ?? .identity }

    var worldToSymbol: CGAffineTransform { focusedSymbol?.worldToSymbol ?? .identity }

    var symbolToView: CGAffineTransform { symbolToWorld.concatenating(viewport.worldToView) }

    var viewToSymbol: CGAffineTransform { viewport.viewToWorld.concatenating(worldToSymbol) }

    var selectedSymbolIds: Set<UUID> {
        switch state {
        case let .active(ids): ids
        default: []
        }
    }

    func selected(id: UUID) -> Bool {
        selectedSymbolIds.contains(id)
    }

    func pathHitTest(pathId: UUID, worldPosition: Point2, threshold: Scalar = 24) -> Bool {
        guard let focusedSymbol,
              let path = path.get(id: pathId) else { return false }
        let symbolPosition = worldPosition.applying(worldToSymbol),
            width = (threshold * Vector2.unitX).applying(viewToSymbol).dx
        guard path.boundingRect.outset(by: width / 2).contains(symbolPosition) else { return false }
        return path.hitPath(width: width).contains(symbolPosition)
    }

    func pathHitTest(worldPosition: Point2, threshold _: Scalar = 24) -> UUID? {
        guard let focusedSymbolId else { return nil }
        return item.allPathItems(symbolId: focusedSymbolId).first { pathHitTest(pathId: $0.id, worldPosition: worldPosition) }?.id
    }
}

// MARK: actions

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

    func select(symbolIds: [UUID]) {
        let _r = subtracer.range(type: .intent, "select \(symbolIds)"); defer { _r() }
        store.update(state: .active(.init(symbolIds)))
    }
}
