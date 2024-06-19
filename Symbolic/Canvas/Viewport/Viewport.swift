import Foundation

private let subtracer = tracer.tagged("viewport")

// MARK: - ViewportInfo

struct ViewportInfo: Equatable {
    let origin: Point2 // world position of the view origin (top left corner)
    let scale: Scalar

    init(origin: Point2, scale: Scalar) {
        self.origin = origin
        self.scale = scale
    }

    init(origin: Point2) { self.init(origin: origin, scale: 1) }

    init() { self.init(origin: .zero, scale: 1) }
}

extension ViewportInfo {
    var worldToView: CGAffineTransform { .init(scale: scale).translatedBy(-Vector2(origin)) }

    var viewToWorld: CGAffineTransform { worldToView.inverted() }

    func worldRect(viewSize: CGSize) -> CGRect { CGRect(x: origin.x, y: origin.y, width: viewSize.width / scale, height: viewSize.height / scale) }
}

extension ViewportInfo: CustomStringConvertible {
    public var description: String { "(\(origin.shortDescription), \(scale.shortDescription))" }
}

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

// MARK: - ViewportUpdateStore

class ViewportUpdateStore: Store {
    @Trackable var blocked: Bool = false
    @Trackable var previousInfo: ViewportInfo = .init()
}

private extension ViewportUpdateStore {
    func update(blocked: Bool) {
        update { $0(\._blocked, blocked) }
    }

    func update(previousInfo: ViewportInfo) {
        update { $0(\._previousInfo, previousInfo) }
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

    var toWorld: CGAffineTransform { info.viewToWorld }
    var toView: CGAffineTransform { info.worldToView }
    var worldRect: CGRect { info.worldRect(viewSize: viewSize) }
}

// MARK: actions

extension ViewportService {
    func setViewSize(_ viewSize: CGSize) {
        store.update(viewSize: viewSize)
    }
}

// MARK: - ViewportUpdater

struct ViewportUpdater {
    let viewport: ViewportStore
    let store: ViewportUpdateStore
}

// MARK: actions

extension ViewportUpdater {
    func setBlocked(_ blocked: Bool) {
        store.update(blocked: blocked)
    }

    func onPanInfo(_ pan: PanInfo?) {
        guard !store.blocked, let pan else { onCommit(); return }
        global.canvasAction.start(continuous: .panViewport)
        global.canvasAction.end(continuous: .pinchViewport)
        let _r = subtracer.range(type: .intent, "pan \(pan)"); defer { _r() }
        let previousInfo = store.previousInfo
        let scale = previousInfo.scale
        let origin = previousInfo.origin - pan.offset / scale
        viewport.update(info: .init(origin: origin, scale: scale))
    }

    func onPinchInfo(_ pinch: PinchInfo?) {
        guard !store.blocked, let pinch else { onCommit(); return }
        global.canvasAction.start(continuous: .pinchViewport)
        global.canvasAction.end(continuous: .panViewport)
        let _r = subtracer.range(type: .intent, "pinch \(pinch)"); defer { _r() }
        let previousInfo = store.previousInfo
        let pinchTransform = CGAffineTransform(translation: pinch.center.offset).centered(at: pinch.center.origin) { $0.scaledBy(pinch.scale) }
        let transformedOrigin = Point2.zero.applying(pinchTransform) // in view reference frame
        let scale = previousInfo.scale * pinch.scale
        let origin = previousInfo.origin - Vector2(transformedOrigin) / scale
        viewport.update(info: .init(origin: origin, scale: scale))
    }
}

// MARK: private

private extension ViewportUpdater {
    func onCommit() {
        global.canvasAction.end(continuous: .panViewport)
        global.canvasAction.end(continuous: .pinchViewport)
        global.canvasAction.end(continuous: .pinchViewport)
        let _r = subtracer.range(type: .intent, "commit"); defer { _r() }
        store.update(previousInfo: viewport.info)
    }
}
