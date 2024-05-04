import Foundation

// MARK: - Line

fileprivate protocol LineImpl {
    func projected(from point: Point2) -> Point2
}

enum Line {
    fileprivate typealias Impl = LineImpl
    struct SlopeIntercept: Impl {
        let m: Scalar, b: Scalar

        func y(x: Scalar) -> Scalar { m * x + b }

        func projected(from point: Point2) -> Point2 {
            let x = (m * (point.y - b) + point.x) / (m * m + 1)
            return Point2(x, y(x: x))
        }
    }

    struct Vertical: Impl {
        let x: Scalar

        func projected(from point: Point2) -> Point2 { Point2(x, point.y) }
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

extension Line: LineImpl {
    func projected(from point: Point2) -> Point2 { impl.projected(from: point) }

    private var impl: Impl {
        switch self {
        case let .slopeIntercept(si): si
        case let .vertical(v): v
        }
    }
}
