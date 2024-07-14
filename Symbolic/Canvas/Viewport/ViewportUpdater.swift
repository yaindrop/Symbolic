import Foundation

private let subtracer = tracer.tagged("viewport")

// MARK: - ViewportUpdateStore

class ViewportUpdateStore: Store {
    @Trackable var updating: Bool = false
    @Trackable var blocked: Bool = false
    @Trackable var previousInfo: ViewportInfo = .init()
}

private extension ViewportUpdateStore {
    func update(updating: Bool) {
        update { $0(\._updating, updating) }
    }

    func update(blocked: Bool) {
        update { $0(\._blocked, blocked) }
    }

    func update(previousInfo: ViewportInfo) {
        update { $0(\._previousInfo, previousInfo) }
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
        withStoreUpdating {
            store.update(updating: true)
            viewport.setInfo(origin: origin, scale: scale)
        }
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
        withStoreUpdating {
            store.update(updating: true)
            viewport.setInfo(origin: origin, scale: scale)
        }
    }

    func zoomTo(rect: CGRect) {
        let worldRect = viewport.worldRect
        let scaledWorldRect = CGRect(center: worldRect.center, size: worldRect.size * 0.8)
        let transform = CGAffineTransform(fit: rect, to: scaledWorldRect).inverted()
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
        withStoreUpdating {
            store.update(updating: false)
            store.update(previousInfo: viewport.info)
        }
    }
}
