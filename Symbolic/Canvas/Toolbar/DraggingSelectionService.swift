import SwiftUI

// MARK: - DraggingSelectionStore

class DraggingSelectionStore: Store {
    @Trackable var from: Point2? = nil
    @Trackable var to: Point2 = .zero
    @Trackable var intersectedItems: [Item] = []
}

private extension DraggingSelectionStore {
    func update(from: Point2?) {
        update {
            $0(\._from, from)
            $0(\._to, from ?? .zero)
        }
    }

    func update(to: Point2) {
        update { $0(\._to, to) }
    }

    func update(intersectedItems: [Item]) {
        update { $0(\._intersectedItems, intersectedItems) }
    }
}

// MARK: - DraggingSelectionService

struct DraggingSelectionService {
    let store: DraggingSelectionStore
    let viewport: ViewportService
    let activeSymbol: ActiveSymbolService
    let path: PathService
    let item: ItemService
}

// MARK: selectors

extension DraggingSelectionService {
    var active: Bool { store.from != nil }

    var boundingRect: CGRect? {
        guard let from = store.from else { return nil }
        return .init(from: from, to: store.to)
    }

    var rectInWorld: CGRect? { boundingRect?.applying(viewport.viewToWorld) }

    func intersects(item: Item) -> Bool {
        guard let pathId = item.path?.id,
              let path = path.get(id: pathId),
              let boundingRect else { return false }
        let transform = viewport.viewToWorld.concatenating(activeSymbol.worldToSymbol),
            bounds = boundingRect.applying(transform)
        return bounds.intersects(path.boundingRect)
    }

    var intersectedRootItems: [Item] {
        guard let symbolId = activeSymbol.focusedSymbolId else { return [] }
        return item.rootItems(symbolId: symbolId).filter {
            item.leafItems(rootId: $0.id)
                .contains { intersects(item: $0) }
        }
    }
}

// MARK: actions

extension DraggingSelectionService {
    func onStart(from: Point2) {
        store.update(from: from)
    }

    func onEnd() {
        store.update(from: nil)
    }

    func onDrag(_ info: PanInfo?) {
        guard active, let info else { return }
        withStoreUpdating {
            store.update(to: info.current)
            store.update(intersectedItems: intersectedRootItems)
        }
    }

    func cancel() {
        store.update(from: nil)
    }
}

// MARK: - DraggingSelectionView

struct DraggingSelectionView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.draggingSelection.boundingRect }) var boundingRect
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension DraggingSelectionView {
    @ViewBuilder var content: some View {
        if let rect = selector.boundingRect {
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.2))
                .stroke(.gray.opacity(0.5))
                .framePosition(rect: rect)
                .allowsHitTesting(false)
        }
    }
}
