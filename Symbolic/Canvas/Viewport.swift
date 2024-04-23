import Combine
import Foundation

struct ViewportInfo: CustomStringConvertible {
    let origin: Point2 // world position of the view origin (top left corner)
    let scale: CGFloat

    init(origin: Point2, scale: CGFloat) {
        self.origin = origin
        self.scale = scale
    }

    init() { self.init(origin: .zero, scale: 1) }

    init(origin: Point2) { self.init(origin: origin, scale: 1) }

    var worldToView: CGAffineTransform { CGAffineTransform(scale: scale).translatedBy(-Vector2(origin)) }
    var viewToWorld: CGAffineTransform { worldToView.inverted() }

    func worldRect(viewSize: CGSize) -> CGRect { CGRect(x: origin.x, y: origin.y, width: viewSize.width / scale, height: viewSize.height / scale) }

    public var description: String { return "ViewportInfo(\(origin.shortDescription), \(scale.shortDescription))" }
}

class Viewport: ObservableObject {
    @Published var info: ViewportInfo = ViewportInfo()
}

// MARK: - ViewportUpdater

class ViewportUpdater: ObservableObject {
    @Published var previousInfo: ViewportInfo = ViewportInfo()

    init(viewport: Viewport, touchContext: MultipleTouchContext) {
        self.viewport = viewport
        touchContext.$panInfo.sink { value in
            guard let info = value else { self.onCommit(); return }
            self.onPanInfo(info)
        }.store(in: &subscriptions)
        touchContext.$pinchInfo.sink { value in
            guard let info = value else { self.onCommit(); return }
            self.onPinchInfo(info)
        }.store(in: &subscriptions)
    }

    // MARK: private

    private let viewport: Viewport
    private var subscriptions = Set<AnyCancellable>()

    private func onPanInfo(_ pan: PanInfo) {
        let scale = previousInfo.scale
        let origin = previousInfo.origin - pan.offset / scale
        viewport.info = ViewportInfo(origin: origin, scale: scale)
    }

    private func onPinchInfo(_ pinch: PinchInfo) {
        let pinchTransform = CGAffineTransform(translation: pinch.center.offset).centered(at: pinch.center.origin) { $0.scaledBy(pinch.scale) }
        let transformedOrigin = Point2.zero.applying(pinchTransform) // in view reference frame
        let scale = previousInfo.scale * pinch.scale
        let origin = previousInfo.origin - Vector2(transformedOrigin) / scale
        viewport.info = ViewportInfo(origin: origin, scale: scale)
    }

    private func onCommit() {
        previousInfo = viewport.info
    }
}
