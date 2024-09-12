import Combine
import SwiftUI

// MARK: - DraggingSelectStore

class DraggingSelectStore: Store {
    @Trackable var from: Point2? = nil
    @Trackable var to: Point2 = .zero
    @Passthrough<[UUID]> var symbolIds
    @Passthrough<[UUID]> var itemIds
}

private extension DraggingSelectStore {
    func update(from: Point2?) {
        update {
            $0(\._from, from)
            $0(\._to, from ?? .zero)
        }
    }

    func update(to: Point2) {
        update { $0(\._to, to) }
    }
}

// MARK: - DraggingSelectService

struct DraggingSelectService {
    let store: DraggingSelectStore
    let path: PathService
    let symbol: SymbolService
    let item: ItemService
    let viewport: ViewportService
    let activeSymbol: ActiveSymbolService
}

// MARK: selectors

extension DraggingSelectService {
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
        let bounds = boundingRect.applying(activeSymbol.viewToSymbol)
        return bounds.intersects(path.boundingRect)
    }
}

// MARK: actions

extension DraggingSelectService {
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
            if let editingSymbolId = activeSymbol.editingSymbolId {
                let selectedItemIds = item.rootItems(symbolId: editingSymbolId)
                    .filter { !$0.locked && item.leafItems(rootId: $0.id).contains { intersects(item: $0) } }
                    .map { $0.id }
                store.itemIds.send(selectedItemIds)
            } else {
                let intersectedSymbols = symbol.symbolMap.values.filter {
                    guard let boundingRect else { return false }
                    return boundingRect.applying(viewport.viewToWorld).intersects($0.boundingRect)
                }
                store.symbolIds.send(intersectedSymbols.map { $0.id })
            }
        }
    }

    func cancel() {
        store.update(from: nil)
    }
}

// MARK: - DraggingSelectView

struct DraggingSelectView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.draggingSelect.boundingRect }) var boundingRect
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension DraggingSelectView {
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
