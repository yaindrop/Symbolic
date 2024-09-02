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
    let activeSymbol: ActiveSymbolService
    let panel: PanelStore
}

// MARK: selectors

extension ViewportUpdater {
    var updating: Bool { store.updating }

    var blocked: Bool { store.blocked }

    var referenceInfo: ViewportInfo { store.referenceInfo }

    var referenceSizedInfo: SizedViewportInfo { .init(size: viewport.viewSize, info: referenceInfo) }
}

// MARK: actions

extension ViewportUpdater {
    func setBlocked(_ blocked: Bool) {
        store.update(blocked: blocked)
    }

    func onPan(_ info: PanInfo) {
        let _r = subtracer.range(type: .intent, "pan \(info)"); defer { _r() }
        let referenceInfo = store.referenceInfo,
            scale = referenceInfo.scale,
            origin = referenceInfo.origin - info.offset / scale
        var sizedInfo = SizedViewportInfo(size: viewport.viewSize, info: .init(origin: origin, scale: scale))
        if let symbol = activeSymbol.editingSymbol {
            let offset = sizedInfo.clampingOffset(by: symbol.boundingRect)
            sizedInfo.info.origin += offset
            sizedInfo.info.origin.x -= (offset.dx > 0 ? 1 : -1) * 50 * log(abs(offset.dx) / 50.0 + 1.0)
            sizedInfo.info.origin.y -= (offset.dy > 0 ? 1 : -1) * 50 * log(abs(offset.dy) / 50.0 + 1.0)
        }
        withStoreUpdating {
            store.update(updating: true)
            viewport.setInfo(sizedInfo.info)
        }
    }

    func onPinch(_ info: PinchInfo) {
        let _r = subtracer.range(type: .intent, "pinch \(info)"); defer { _r() }
        let referenceInfo = store.referenceInfo,
            pinchTransform = CGAffineTransform(translation: info.center.offset).centered(at: info.center.origin) { $0.scaledBy(info.scale) },
            transformedOrigin = Point2.zero.applying(pinchTransform), // in view reference frame
            scale = referenceInfo.scale * info.scale,
            origin = referenceInfo.origin - Vector2(transformedOrigin) / scale
        var sizedInfo = SizedViewportInfo(size: viewport.viewSize, info: .init(origin: origin, scale: scale))
        if let symbol = activeSymbol.editingSymbol {
            let offset = sizedInfo.clampingOffset(by: symbol.boundingRect)
            sizedInfo.info.origin += offset
            sizedInfo.info.origin -= offset / 3
            sizedInfo.info.origin.x -= (offset.dx > 0 ? 1 : -1) * 50 * log(abs(offset.dx) / 50.0 + 1.0)
            sizedInfo.info.origin.y -= (offset.dy > 0 ? 1 : -1) * 50 * log(abs(offset.dy) / 50.0 + 1.0)
        }
        withStoreUpdating {
            store.update(updating: true)
            viewport.setInfo(sizedInfo.info)
        }
    }

    func onCommit() {
        let _r = subtracer.range(type: .intent, "commit"); defer { _r() }
        var sizedInfo = viewport.sizedInfo
        if let symbol = activeSymbol.editingSymbol {
            sizedInfo = sizedInfo.clamped(by: symbol.boundingRect)
        }
        withStoreUpdating(configs: .init(animation: .fast)) {
            store.update(updating: false)
            viewport.setInfo(sizedInfo.info)
            store.update(referenceInfo: viewport.info)
        }
    }

    func zoomTo(rect: CGRect, ratio: Scalar = 0.8) {
        assert(rect.size.width > 0 && rect.height > 0)
        let freeSpace = panel.freeSpace
        let _r = subtracer.range(type: .intent, "zoomTo \(rect) in \(freeSpace)"); defer { _r() }
        let worldRect = viewport.worldRect,
            targetRect = CGRect(center: freeSpace.center, size: freeSpace.size * ratio).applying(viewport.viewToWorld),
            transform = CGAffineTransform(fit: rect, to: targetRect).inverted(),
            newWorldRect = worldRect.applying(transform),
            origin = newWorldRect.origin,
            scale = viewport.viewSize.width / newWorldRect.width
        withStoreUpdating(configs: .init(animation: .fast)) {
            viewport.setInfo(.init(origin: origin, scale: scale))
            store.update(referenceInfo: viewport.info)
        }
    }
}
