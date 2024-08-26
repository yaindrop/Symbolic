import Foundation

private let subtracer = tracer.tagged("viewport")

// MARK: - ViewportUpdateStore

class ViewportUpdateStore: Store {
    @Trackable var updating: Bool = false
    @Trackable var blocked: Bool = false
    @Trackable var referenceInfo: ViewportInfo = .init()
}

private extension ViewportUpdateStore {
    func update(updating: Bool) {
        update { $0(\._updating, updating) }
    }

    func update(blocked: Bool) {
        update { $0(\._blocked, blocked) }
    }

    func update(referenceInfo: ViewportInfo) {
        update { $0(\._referenceInfo, referenceInfo) }
    }
}

// MARK: - ViewportUpdater

struct ViewportUpdater {
    let store: ViewportUpdateStore
    let viewport: ViewportService
    let panel: PanelStore
}

extension ViewportUpdater {
    var referenceInfo: ViewportInfo { store.referenceInfo }

    var referenceSizedInfo: SizedViewportInfo { .init(size: viewport.viewSize, info: referenceInfo) }
}

// MARK: actions

extension ViewportUpdater {
    func setBlocked(_ blocked: Bool) {
        store.update(blocked: blocked)
    }

    func onPan(_ info: PanInfo) {
        guard !store.blocked else { onCommit(); return }
        global.canvasAction.start(continuous: .panViewport)
        global.canvasAction.end(continuous: .pinchViewport)
        let _r = subtracer.range(type: .intent, "pan \(info)"); defer { _r() }
        let referenceInfo = store.referenceInfo
        let scale = referenceInfo.scale
        let origin = referenceInfo.origin - info.offset / scale
        withStoreUpdating {
            store.update(updating: true)
            viewport.setInfo(origin: origin, scale: scale)
        }
    }

    func onPinch(_ info: PinchInfo) {
        guard !store.blocked else { onCommit(); return }
        global.canvasAction.start(continuous: .pinchViewport)
        global.canvasAction.end(continuous: .panViewport)
        let _r = subtracer.range(type: .intent, "pinch \(info)"); defer { _r() }
        let referenceInfo = store.referenceInfo
        let pinchTransform = CGAffineTransform(translation: info.center.offset).centered(at: info.center.origin) { $0.scaledBy(info.scale) }
        let transformedOrigin = Point2.zero.applying(pinchTransform) // in view reference frame
        let scale = referenceInfo.scale * info.scale
        let origin = referenceInfo.origin - Vector2(transformedOrigin) / scale
        withStoreUpdating {
            store.update(updating: true)
            viewport.setInfo(origin: origin, scale: scale)
        }
    }

    func onCommit() {
        global.canvasAction.end(continuous: .panViewport)
        global.canvasAction.end(continuous: .pinchViewport)
        let _r = subtracer.range(type: .intent, "commit"); defer { _r() }
        withStoreUpdating {
            store.update(updating: false)
            store.update(referenceInfo: viewport.info)
        }
    }

    func zoomTo(rect: CGRect, ratio: Scalar = 0.8) {
        assert(rect.size.width > 0 && rect.height > 0)
        let freeSpace = global.panel.freeSpace
        let _r = subtracer.range(type: .intent, "zoomTo \(rect) in \(freeSpace)"); defer { _r() }
        let worldRect = viewport.worldRect
        let targetRect = CGRect(center: freeSpace.center, size: freeSpace.size * ratio).applying(viewport.viewToWorld)
        let transform = CGAffineTransform(fit: rect, to: targetRect).inverted()
        let newWorldRect = worldRect.applying(transform)
        let origin = newWorldRect.origin
        let scale = viewport.viewSize.width / newWorldRect.width
        withStoreUpdating(configs: .init(animation: .fast)) {
            viewport.setInfo(origin: origin, scale: scale)
            store.update(referenceInfo: viewport.info)
        }
    }
}
