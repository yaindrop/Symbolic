import Foundation

// MARK: - ViewportStore

class ViewportStore: Store {
    @Trackable var info: ViewportInfo = .init()
    @Trackable var viewSize: CGSize = .zero
}

private extension ViewportStore {
    func update(info: ViewportInfo) {
        update { $0(\._info, info) }
    }

    func update(viewSize: CGSize) {
        update { $0(\._viewSize, viewSize) }
    }
}

// MARK: - ViewportService

struct ViewportService {
    let store: ViewportStore
}

// MARK: selectors

extension ViewportService {
    var info: ViewportInfo { store.info }
    var viewSize: CGSize { store.viewSize }

    var viewToWorld: CGAffineTransform { info.viewToWorld }
    var worldToView: CGAffineTransform { info.worldToView }

    var sizedInfo: SizedViewportInfo { .init(size: viewSize, info: info) }
    var worldRect: CGRect { sizedInfo.worldRect }
    var center: Point2 { sizedInfo.center }
}

// MARK: actions

extension ViewportService {
    func setViewSize(_ viewSize: CGSize) {
        store.update(viewSize: viewSize)
    }

    func setInfo(origin: Point2, scale: Scalar) {
        store.update(info: .init(origin: origin, scale: scale))
    }
}
