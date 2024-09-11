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
        applyOverscroll(to: &sizedInfo, bouncing: true)
        withStoreUpdating {
            store.update(updating: true)
            viewport.setInfo(sizedInfo.info)
        }
    }

    func onPinch(_ info: PinchInfo) {
        let _r = subtracer.range(type: .intent, "pinch \(info)"); defer { _r() }
        let referenceInfo = store.referenceInfo,
            clampedScale = scaleRange.clamp(referenceInfo.scale * info.scale) / referenceInfo.scale,
            pinchTransform = CGAffineTransform(translation: info.center.offset).centered(at: info.center.origin) { $0.scaledBy(clampedScale) },
            transformedOrigin = Point2.zero.applying(pinchTransform), // in view reference frame
            scale = referenceInfo.scale * clampedScale,
            origin = referenceInfo.origin - Vector2(transformedOrigin) / scale
        var sizedInfo = SizedViewportInfo(size: viewport.viewSize, info: .init(origin: origin, scale: scale))
        applyOverscroll(to: &sizedInfo)
        withStoreUpdating {
            store.update(updating: true)
            viewport.setInfo(sizedInfo.info)
        }
    }

    func onCommit() {
        let _r = subtracer.range(type: .intent, "commit"); defer { _r() }
        var sizedInfo = viewport.sizedInfo
        applyOverscroll(to: &sizedInfo)
        withStoreUpdating(.animation(.fast)) {
            store.update(updating: false)
            viewport.setInfo(sizedInfo.info)
            store.update(referenceInfo: viewport.info)
        }
    }

    func zoomTo(worldRect rect: CGRect, ratio: Scalar = 0.8) {
        assert(rect.size.width > 0 && rect.height > 0)
        let freeSpace = panel.freeSpace
        let _r = subtracer.range(type: .intent, "zoomTo \(rect) in \(freeSpace)"); defer { _r() }
        let worldRect = viewport.worldRect,
            targetRect = CGRect(center: freeSpace.center, size: freeSpace.size * ratio).applying(viewport.viewToWorld),
            transform = CGAffineTransform(fit: rect, to: targetRect).inverted(),
            newWorldRect = worldRect.applying(transform),
            center = newWorldRect.center,
            scale = scaleRange.clamp(viewport.viewSize.width / newWorldRect.width)
        var sizedInfo = SizedViewportInfo(size: viewport.viewSize, center: center, scale: scale)
        applyOverscroll(to: &sizedInfo)
        withStoreUpdating(.animation(.fast)) {
            viewport.setInfo(sizedInfo.info)
            store.update(referenceInfo: viewport.info)
        }
    }
}

private extension ViewportUpdater {
    var scaleRange: ClosedRange<Scalar> { 0.04 ... 25 }

    var overscrollOutset: Scalar { 96 }

    var overscrollBounceDistance: Scalar { 24 }

    func applyOverscroll(to info: inout SizedViewportInfo, bouncing: Bool = false) {
        guard let symbol = activeSymbol.editingSymbol else { return }
        let rect = symbol.boundingRect.outset(by: overscrollOutset / info.scale),
            offset = info.clampingOffset(by: rect)
        guard !offset.isZero else { return }
        info.info.origin += offset
        if bouncing {
            if rect.width > info.worldRect.width {
                info.info.origin -= Vector2(x: overscroll(value: offset.dx, scale: info.scale))
            }
            if rect.height > info.worldRect.height {
                info.info.origin -= Vector2(y: overscroll(value: offset.dy, scale: info.scale))
            }
        }
    }

    func overscroll(value: Scalar, scale: Scalar) -> Scalar {
        let k = overscrollBounceDistance / scale,
            sign = value > 0 ? 1.0 : -1.0,
            magnitude = abs(value)
        return sign * k * log(1 + magnitude / k)
    }
}

extension ViewportUpdater {
    func zoomToEditingSymbol() {
        guard let symbol = activeSymbol.editingSymbol else { return }
        zoomTo(worldRect: symbol.boundingRect)
    }
}
