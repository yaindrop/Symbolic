import SwiftUI

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

    static func vertical(x: Scalar) -> Line { .vertical(.init(x: x)) }
    static func horizontal(y: Scalar) -> Line { .slopeIntercept(.init(m: 0, b: y)) }

    static var xAxis: Line { .horizontal(y: 0) }
    static var yAxis: Line { .vertical(x: 0) }

    init(p0: Point2, p1: Point2) {
        if p0.x == p1.x {
            self = .vertical(x: p0.x)
        } else {
            let m = (p1.y - p0.y) / (p1.x - p0.x)
            let b = p0.y - m * p0.x
            self = .slopeIntercept(.init(m: m, b: b))
        }
    }

    init(point: Point2, angle: Angle) {
        if angle.isRight {
            self = .vertical(x: point.x)
        } else {
            let m = tan(angle.radians)
            let b = point.y - m * point.x
            self = .slopeIntercept(.init(m: m, b: b))
        }
    }

    init(b: Scalar, angle: Angle) {
        if angle.isRight {
            self = .vertical(x: 0)
        } else {
            let m = tan(angle.radians)
            self = .slopeIntercept(.init(m: m, b: b))
        }
    }
}

// MARK: Impl

private protocol LineImpl: Equatable {
    func projected(from point: Point2) -> Point2
    func parallel(to other: Line) -> Bool
    func intersection(with other: Line) -> Point2?
}

extension Line.SlopeIntercept: LineImpl {
    func projected(from point: Point2) -> Point2 {
        self.point(x: (m * (point.y - b) + point.x) / (m * m + 1))
    }

    func parallel(to other: Line) -> Bool {
        switch other {
        case let .slopeIntercept(other): m == other.m
        case .vertical: false
        }
    }

    func intersection(with other: Line) -> Point2? {
        switch other {
        case let .slopeIntercept(other):
            guard m != other.m else { return nil }
            return point(x: (other.b - b) / (m - other.m))
        case let .vertical(other):
            return point(x: other.x)
        }
    }
}

extension Line.Vertical: LineImpl {
    func projected(from point: Point2) -> Point2 {
        self.point(y: point.y)
    }

    func parallel(to other: Line) -> Bool {
        switch other {
        case .slopeIntercept: false
        case .vertical: true
        }
    }

    func intersection(with other: Line) -> Point2? {
        switch other {
        case let .slopeIntercept(other): other.point(x: x)
        case .vertical: nil
        }
    }
}

extension Line: LineImpl {
    fileprivate typealias Impl = any LineImpl

    func projected(from point: Point2) -> Point2 { impl.projected(from: point) }

    func parallel(to other: Line) -> Bool { impl.parallel(to: other) }

    func intersection(with other: Line) -> Point2? { impl.intersection(with: other) }

    func distance(to point: Point2) -> Scalar {
        point.distance(to: projected(from: point))
    }

    private var impl: Impl {
        switch self {
        case let .slopeIntercept(si): si
        case let .vertical(v): v
        }
    }
}
