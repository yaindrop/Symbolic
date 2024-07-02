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
}

// MARK: selectors

extension DraggingSelectionService {
    var active: Bool { store.from != nil }

    var rect: CGRect? {
        guard let from = store.from else { return nil }
        return .init(from: from, to: store.to)
    }

    var rectInWorld: CGRect? { rect?.applying(viewport.toWorld) }

    func intersects(item: Item) -> Bool {
        guard let rectInWorld else { return false }
        guard let pathId = item.pathId else { return false }
        guard let path = global.path.get(id: pathId) else { return false }
        return path.boundingRect.intersects(rectInWorld)
    }

    var intersectedRootItems: [Item] {
        global.item.rootItems.filter {
            global.item.leafItems(rootItemId: $0.id)
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
        @Selected({ global.draggingSelection.rect }) var rect
        @Selected({ global.viewport.toView }) var toView
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
        if let rect = selector.rect {
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.2))
                .stroke(.gray.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
        }
    }
}
