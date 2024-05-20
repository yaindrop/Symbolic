import Combine
import Foundation
import SwiftUI

class PendingSelectionStore: Store {
    @Trackable var from: Point2? = nil
    @Trackable var to: Point2 = .zero

    var active: Bool { from != nil }

    func onStart(from: Point2) {
        update {
            $0(\._from, from)
            $0(\._to, from)
        }
    }

    func onEnd() {
        update {
            $0(\._from, nil)
            $0(\._to, .zero)
        }
    }

    fileprivate func onPan(_ info: PanInfo?) {
        guard active, let info else { return }
        update { $0(\._to, info.current) }
    }

    fileprivate var subscriptions = Set<AnyCancellable>()
}

struct PendingSelectionService {
    let pathStore: PathStore
    let viewport: ViewportService
    let store: PendingSelectionStore

    var active: Bool { store.active }

    var rect: CGRect? {
        guard let from = store.from else { return nil }
        return .init(from: from, to: store.to)
    }

    var intersectedPaths: [Path]? {
        rect.map {
            let rectInWorld = $0.applying(viewport.toWorld)
            return pathStore.paths.filter { $0.boundingRect.intersects(rectInWorld) }
        }
    }

    func subscribe(to multipleTouch: MultipleTouchModel) {
        multipleTouch.$panInfo
            .sink { self.store.onPan($0) }
            .store(in: &store.subscriptions)
    }
}

struct PendingSelection: View {
    @Selected var pendingSelectionRect = global.pendingSelection.rect
    @Selected var intersectedPaths = global.pendingSelection.intersectedPaths
    @Selected var toView = global.viewport.toView

    var body: some View {
        if let rect = pendingSelectionRect {
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.2))
                .stroke(.gray.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
        }
        if let intersectedPaths {
            ForEach(intersectedPaths) {
                let rect = $0.boundingRect.applying(toView)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue.opacity(0.2))
                    .stroke(.blue.opacity(0.5))
                    .frame(width: rect.width, height: rect.height)
                    .position(rect.center)
            }
        }
    }
}
