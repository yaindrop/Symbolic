import SwiftUI

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
