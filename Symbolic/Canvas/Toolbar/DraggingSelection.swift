import Combine
import Foundation
import SwiftUI

class DraggingSelectionStore: Store {
    @Trackable var from: Point2? = nil
    @Trackable var to: Point2 = .zero
    @Trackable var intersectedItems: [Item] = []

    var active: Bool { from != nil }

    fileprivate func update(from: Point2?) {
        update {
            $0(\._from, from)
            $0(\._to, from ?? .zero)
        }
    }

    fileprivate func update(to: Point2) {
        update { $0(\._to, to) }
    }

    fileprivate func update(intersectedItems: [Item]) {
        update { $0(\._intersectedItems, intersectedItems) }
    }
}

struct DraggingSelectionService {
    let pathStore: PathStore
    let viewport: ViewportService
    let store: DraggingSelectionStore

    var active: Bool { store.active }

    var rect: CGRect? {
        guard let from = store.from else { return nil }
        return .init(from: from, to: store.to)
    }

    var rectInWorld: CGRect? { rect?.applying(viewport.toWorld) }

    func intersects(item: Item) -> Bool {
        guard let rectInWorld else { return false }
        guard let pathId = item.pathId else { return false }
        guard let path = global.path.path(id: pathId) else { return false }
        return path.boundingRect.intersects(rectInWorld)
    }

    var intersectedRootItems: [Item] {
        global.item.rootItems.filter {
            global.item.leafItems(rootItemId: $0.id)
                .contains { intersects(item: $0) }
        }
    }

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

struct DraggingSelectionView: View {
    @Selected private var rect = global.draggingSelection.rect
    @Selected private var toView = global.viewport.toView

    var body: some View {
        if let rect {
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.2))
                .stroke(.gray.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
        }
    }
}
