import Foundation

// MARK: - Line

enum Line {
    struct SlopeIntercept {
        let m: Scalar, b: Scalar

        func y(x: Scalar) -> Scalar { m * x + b }

        func point(x: Scalar) -> Point2 { .init(x, y(x: x)) }
    }

    struct Vertical {
        let x: Scalar

        func point(y: Scalar) -> Point2 { .init(x, y) }
    }

    case slopeIntercept(SlopeIntercept)
    case vertical(Vertical)

    init(p0: Point2, p1: Point2) {
        if p0.x == p1.x {
            self = .vertical(.init(x: p0.x))
        } else {
            let m = (p1.y - p0.y) / (p1.x - p0.x)
            let b = p0.y - m * p0.x
            self = .slopeIntercept(.init(m: m, b: b))
        }
    }
}

// MARK: Impl

private protocol LineImpl: Equatable {
    func projected(from point: Point2) -> Point2
}

extension Line.SlopeIntercept: LineImpl {
    func projected(from point: Point2) -> Point2 { self.point(x: (m * (point.y - b) + point.x) / (m * m + 1)) }
}

extension Line.Vertical: LineImpl {
    func projected(from point: Point2) -> Point2 { self.point(y: point.y) }
}

extension Line: LineImpl {
    fileprivate typealias Impl = any LineImpl

    func projected(from point: Point2) -> Point2 { impl.projected(from: point) }

    private var impl: Impl {
        switch self {
        case let .slopeIntercept(si): si
        case let .vertical(v): v
        }
    }
}
