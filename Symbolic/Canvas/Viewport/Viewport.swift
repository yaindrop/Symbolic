import SwiftUI

private let subtracer = tracer.tagged("viewport")

// MARK: - ViewportInfo

struct ViewportInfo: Equatable {
    let origin: Point2 // world position of the view origin (top left corner)
    let scale: Scalar

    init(origin: Point2 = .zero, scale: Scalar = 1) {
        self.origin = origin
        self.scale = scale
    }
}

extension ViewportInfo {
    var worldToView: CGAffineTransform { .init(scale: scale).translatedBy(-Vector2(origin)) }
    var viewToWorld: CGAffineTransform { worldToView.inverted() }
}

extension ViewportInfo: CustomStringConvertible {
    public var description: String { "(\(origin.shortDescription), \(scale.shortDescription))" }
}

// MARK: - SizedViewportInfo

struct SizedViewportInfo: Equatable {
    let size: CGSize
    let info: ViewportInfo

    init(size: CGSize, info: ViewportInfo) {
        self.size = size
        self.info = info
    }

    init(size: CGSize, worldRect: CGRect) {
        self.size = size
        info = .init(origin: worldRect.origin, scale: size.width / worldRect.width)
    }

    init(size: CGSize, center: Point2, scale: Scalar) {
        let worldRect = CGRect(center: center, size: size / scale)
        self.size = size
        info = .init(origin: worldRect.origin, scale: scale)
    }
}

extension SizedViewportInfo {
    var origin: Point2 { info.origin }
    var scale: Scalar { info.scale }
    var worldToView: CGAffineTransform { info.worldToView }
    var viewToWorld: CGAffineTransform { info.viewToWorld }

    var worldRect: CGRect { .init(origin: info.origin, size: size / info.scale) }
    var center: Point2 { worldRect.center }
}

extension SizedViewportInfo: Animatable {
    var animatableData: CGRect.AnimatableData {
        get { worldRect.animatableData }
        set {
            var worldRect = worldRect
            worldRect.animatableData = newValue
            self = .init(size: size, worldRect: worldRect)
        }
    }
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

    var sizedInfo: SizedViewportInfo { .init(size: viewSize, info: info) }
    var worldRect: CGRect { sizedInfo.worldRect }
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

// MARK: - ViewportUpdater

struct ViewportUpdater {
    let store: ViewportUpdateStore
    let viewport: ViewportService
    let panel: PanelStore
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
        viewport.setInfo(origin: origin, scale: scale)
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
        viewport.setInfo(origin: origin, scale: scale)
    }

    func zoomTo(rect: CGRect) {
        let worldRect = viewport.worldRect
        let transform = CGAffineTransform(fit: rect, to: worldRect).inverted()
        let newWorldRect = worldRect.applying(transform)
        let origin = newWorldRect.origin
        let scale = viewport.viewSize.width / newWorldRect.width
        withStoreUpdating(configs: .init(animation: .fast)) {
            viewport.setInfo(origin: origin, scale: scale)
            store.update(previousInfo: viewport.info)
        }
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
