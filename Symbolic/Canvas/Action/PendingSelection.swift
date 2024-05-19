import Combine
import Foundation
import SwiftUI

class PendingSelectionModel: Store {
    @Trackable var from: Point2? = nil
    @Trackable var to: Point2 = .zero

    var active: Bool { from != nil }
    var rect: CGRect? {
        guard let from else { return nil }
        return .init(from: from, to: to)
    }

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

    func subscribe(to multipleTouch: MultipleTouchModel) {
        multipleTouch.$panInfo
            .sink { self.onPan($0) }
            .store(in: &subscriptions)
    }

    private func onPan(_ info: PanInfo?) {
        guard active, let info else { return }
        update { $0(\._to, info.current) }
    }

    private var subscriptions = Set<AnyCancellable>()
}

var selectPendingRect: CGRect? { store.pendingSelection.rect }

struct PendingSelection: View {
    @Selected var pendingSelectionRect = selectPendingRect
    @Selected var intersectedPaths = selectPendingRect.map {
        let rectInWorld = $0.applying(store.viewport.toWorld)
        return store.path.paths.filter { $0.boundingRect.intersects(rectInWorld) }
    }

    @Selected var toView = store.viewport.toView

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
