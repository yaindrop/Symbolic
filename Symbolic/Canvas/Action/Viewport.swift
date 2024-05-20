import Combine
import Foundation

// MARK: - ViewportInfo

struct ViewportInfo: Equatable {
    let origin: Point2 // world position of the view origin (top left corner)
    let scale: Scalar

    var worldToView: CGAffineTransform { .init(scale: scale).translatedBy(-Vector2(origin)) }

    var viewToWorld: CGAffineTransform { worldToView.inverted() }

    func worldRect(viewSize: CGSize) -> CGRect { CGRect(x: origin.x, y: origin.y, width: viewSize.width / scale, height: viewSize.height / scale) }

    init(origin: Point2, scale: Scalar) {
        self.origin = origin
        self.scale = scale
    }

    init(origin: Point2) { self.init(origin: origin, scale: 1) }

    init() { self.init(origin: .zero, scale: 1) }
}

extension ViewportInfo: CustomStringConvertible {
    public var description: String { return "(\(origin.shortDescription), \(scale.shortDescription))" }
}

// MARK: - stores

class ViewportStore: Store {
    @Trackable var info: ViewportInfo = .init()

    fileprivate func update(info: ViewportInfo) {
        update { $0(\._info, info) }
    }
}

class ViewportUpdateStore: Store {
    @Trackable var blocked: Bool = false
    @Trackable var previousInfo: ViewportInfo = .init()

    func setBlocked(_ blocked: Bool) {
        update { $0(\._blocked, blocked) }
    }

    fileprivate func update(previousInfo: ViewportInfo) {
        update { $0(\._previousInfo, previousInfo) }
    }

    fileprivate var subscriptions = Set<AnyCancellable>()
}

// MARK: - services

struct ViewportService {
    let store: ViewportStore

    var toWorld: CGAffineTransform { store.info.viewToWorld }
    var toView: CGAffineTransform { store.info.worldToView }
}

struct ViewportUpdater {
    let viewport: ViewportStore
    let store: ViewportUpdateStore

    func subscribe(to multipleTouch: MultipleTouchModel) {
        multipleTouch.$panInfo
            .sink { value in
                guard !self.store.blocked, let info = value else { self.onCommit(); return }
                self.onPanInfo(info)
            }
            .store(in: &store.subscriptions)
        multipleTouch.$pinchInfo
            .sink { value in
                guard !self.store.blocked, let info = value else { self.onCommit(); return }
                self.onPinchInfo(info)
            }
            .store(in: &store.subscriptions)
    }

    // MARK: private

    private func onPanInfo(_ pan: PanInfo) {
        let _r = tracer.range("Viewport pan \(pan)", type: .intent); defer { _r() }
        let previousInfo = store.previousInfo
        let scale = previousInfo.scale
        let origin = previousInfo.origin - pan.offset / scale
        viewport.update(info: .init(origin: origin, scale: scale))
    }

    private func onPinchInfo(_ pinch: PinchInfo) {
        let _r = tracer.range("Viewport pinch \(pinch)", type: .intent); defer { _r() }
        let previousInfo = store.previousInfo
        let pinchTransform = CGAffineTransform(translation: pinch.center.offset).centered(at: pinch.center.origin) { $0.scaledBy(pinch.scale) }
        let transformedOrigin = Point2.zero.applying(pinchTransform) // in view reference frame
        let scale = previousInfo.scale * pinch.scale
        let origin = previousInfo.origin - Vector2(transformedOrigin) / scale
        viewport.update(info: .init(origin: origin, scale: scale))
    }

    private func onCommit() {
        let _r = tracer.range("Viewport commit", type: .intent); defer { _r() }
        store.update(previousInfo: viewport.info)
    }
}
