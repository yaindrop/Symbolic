import Combine
import Foundation

struct ViewportInfo {
    let origin: Point2 // world position of the view origin (top left corner)
    let scale: Scalar
    let worldToView: CGAffineTransform
    let viewToWorld: CGAffineTransform

    func worldRect(viewSize: CGSize) -> CGRect { CGRect(x: origin.x, y: origin.y, width: viewSize.width / scale, height: viewSize.height / scale) }

    init(origin: Point2, scale: Scalar) {
        self.origin = origin
        self.scale = scale
        worldToView = CGAffineTransform(scale: scale).translatedBy(-Vector2(origin))
        viewToWorld = worldToView.inverted()
    }

    init(origin: Point2) { self.init(origin: origin, scale: 1) }

    init() { self.init(origin: .zero, scale: 1) }
}

extension ViewportInfo: CustomStringConvertible {
    public var description: String { return "(\(origin.shortDescription), \(scale.shortDescription))" }
}

class Viewport: ObservableObject {
    @Published fileprivate(set) var info: ViewportInfo = .init()

    var toWorld: CGAffineTransform { info.viewToWorld }
    var toView: CGAffineTransform { info.worldToView }
}

// MARK: - ViewportUpdater

class ViewportUpdater: ObservableObject {
    @Published var blocked: Bool = false
    @Published private(set) var previousInfo: ViewportInfo = .init()

    init(viewport: Viewport, touchContext: MultipleTouchContext) {
        self.viewport = viewport
        touchContext.$panInfo
            .sink { value in
                guard !self.blocked, let info = value else { self.onCommit(); return }
                self.onPanInfo(info)
            }
            .store(in: &subscriptions)
        touchContext.$pinchInfo
            .sink { value in
                guard !self.blocked, let info = value else { self.onCommit(); return }
                self.onPinchInfo(info)
            }
            .store(in: &subscriptions)
    }

    // MARK: private

    private let viewport: Viewport
    private var subscriptions = Set<AnyCancellable>()

    private func onPanInfo(_ pan: PanInfo) {
        let scale = previousInfo.scale
        let origin = previousInfo.origin - pan.offset / scale
        viewport.info = .init(origin: origin, scale: scale)
    }

    private func onPinchInfo(_ pinch: PinchInfo) {
        let pinchTransform = CGAffineTransform(translation: pinch.center.offset).centered(at: pinch.center.origin) { $0.scaledBy(pinch.scale) }
        let transformedOrigin = Point2.zero.applying(pinchTransform) // in view reference frame
        let scale = previousInfo.scale * pinch.scale
        let origin = previousInfo.origin - Vector2(transformedOrigin) / scale
        viewport.info = .init(origin: origin, scale: scale)
    }

    private func onCommit() {
        previousInfo = viewport.info
    }
}
