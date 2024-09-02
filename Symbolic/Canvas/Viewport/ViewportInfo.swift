import SwiftUI

// MARK: - ViewportInfo

struct ViewportInfo: Equatable {
    var origin: Point2 // world position of the view origin (top left corner)
    var scale: Scalar

    init(origin: Point2 = .zero, scale: Scalar = 1) {
        let scale = scale != 0 ? scale : 1
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
    var size: CGSize
    var info: ViewportInfo

    init(size: CGSize, info: ViewportInfo) {
        self.size = size
        self.info = info
    }

    init?(size: CGSize, worldRect: CGRect) {
        guard worldRect.width != 0 else { return nil }
        self.size = size
        info = .init(origin: worldRect.origin, scale: size.width / worldRect.width)
    }

    init(size: CGSize, center: Point2, scale: Scalar = 1) {
        let scale = scale != 0 ? scale : 1
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

    func clampingOffset(by rect: CGRect) -> Vector2 {
        let worldRect = worldRect
        var offset = Vector2.zero
        if worldRect.width < rect.width {
            if worldRect.minX < rect.minX {
                offset.dx = rect.minX - worldRect.minX
            } else if worldRect.maxX > rect.maxX {
                offset.dx = rect.maxX - worldRect.maxX
            }
        } else {
            offset.dx = rect.midX - worldRect.midX
        }
        if worldRect.height < rect.height {
            if worldRect.minY < rect.minY {
                offset.dy = rect.minY - worldRect.minY
            } else if worldRect.maxY > rect.maxY {
                offset.dy = rect.maxY - worldRect.maxY
            }
        } else {
            offset.dy = rect.midY - worldRect.midY
        }
        return offset
    }

    func clamped(by rect: CGRect) -> Self {
        .init(size: size, center: center + clampingOffset(by: rect), scale: scale)
    }
}

extension SizedViewportInfo: Animatable {
    var animatableData: CGRect.AnimatableData {
        get { worldRect.animatableData }
        set {
            var worldRect = worldRect
            worldRect.animatableData = newValue
            self = .init(size: size, worldRect: worldRect) ?? .init(size: size, center: .zero)
        }
    }
}

// MARK: - EnvironmentValues

private struct SizedViewportInfoKey: EnvironmentKey {
    static let defaultValue: SizedViewportInfo = .init(size: .zero, info: .init())
}

private struct TransformToViewKey: EnvironmentKey {
    static let defaultValue: CGAffineTransform = .identity
}

extension EnvironmentValues {
    var sizedViewport: SizedViewportInfo {
        get { self[SizedViewportInfoKey.self] }
        set { self[SizedViewportInfoKey.self] = newValue }
    }

    var transformToView: CGAffineTransform {
        get { self[TransformToViewKey.self] }
        set { self[TransformToViewKey.self] = newValue }
    }
}
