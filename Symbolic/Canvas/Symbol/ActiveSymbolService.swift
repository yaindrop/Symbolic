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
    @Trackable var gridIndex: Int = 0
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

    var gridIndex: Int { store.gridIndex }

    var activeSymbolIds: Set<UUID> {
        switch state {
        case .none: []
        case let .active(ids): ids
        case let .focused(id): [id]
        case let .editing(id): [id]
        }
    }

    // MARK: focused

    var focusedSymbolId: UUID? {
        switch state {
        case let .focused(id): id
        case let .editing(id): id
        default: nil
        }
    }

    var focusedSymbol: Symbol? { focusedSymbolId.map { symbol.get(id: $0) } }

    var focusedSymbolItem: Item.Symbol? { focusedSymbolId.map { item.symbol(id: $0) } }

    // MARK: editing

    var editingSymbolId: UUID? { if case let .editing(id) = state { id } else { nil } }

    var editingSymbol: Symbol? { editingSymbolId.map { symbol.get(id: $0) } }

    var editingSymbolItem: Item.Symbol? { editingSymbolId.map { item.symbol(id: $0) } }

    static var editingBoundsOutset: Scalar { 12 }

    static var editingBoundsRadius: Scalar { 6 }

    // MARK: transform

    var symbolToWorld: CGAffineTransform { focusedSymbol?.symbolToWorld ?? .identity }

    var worldToSymbol: CGAffineTransform { focusedSymbol?.worldToSymbol ?? .identity }

    var symbolToView: CGAffineTransform { symbolToWorld.concatenating(viewport.worldToView) }

    var viewToSymbol: CGAffineTransform { viewport.viewToWorld.concatenating(worldToSymbol) }

    // MARK: selection

    var selectedSymbolIds: Set<UUID> {
        switch state {
        case let .active(ids): ids
        default: []
        }
    }

    func selected(id: UUID) -> Bool {
        selectedSymbolIds.contains(id)
    }

    var selectionBounds: CGRect? {
        .init(union: selectedSymbolIds.compactMap { symbol.get(id: $0.id)?.boundingRect })
    }

    static var selectionBoundsOutset: Scalar { 12 }

    // MARK: hit test

    func pathHitTest(pathId: UUID, worldPosition: Point2, threshold: Scalar = 24) -> Bool {
        guard editingSymbolId != nil,
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

    // MARK: grid

    var grids: [Grid] { editingSymbol?.grids ?? [] }

    var grid: Grid? {
        let grids = grids
        guard grids.indices.contains(gridIndex) else { return nil }
        return grids[gridIndex]
    }

    func snap(_ point: Point2) -> Point2 {
        grid?.snap(point) ?? point
    }

    func snapped(_ point: Point2) -> Grid? {
        guard let editingSymbol else { return nil }
        return editingSymbol.grids.first { $0.snapped(point) }
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
