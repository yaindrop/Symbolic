import Foundation

// MARK: - Line

fileprivate protocol LineImpl {
    func projected(from point: Point2) -> Point2
}

enum Line {
    fileprivate typealias Impl = LineImpl
    struct SlopeIntercept: Impl {
        let m: CGFloat, b: CGFloat

        func y(x: CGFloat) -> CGFloat { m * x + b }

        func projected(from point: Point2) -> Point2 {
            let x = (m * (point.y - b) + point.x) / (m * m + 1)
            return Point2(x, y(x: x))
        }
    }

    struct Vertical: Impl {
        let x: CGFloat

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

// MARK: - LineSegment

fileprivate protocol LineSegmentImpl: Parametrizable, InverseParametrizable {
    var line: Line { get }
    var start: Point2 { get }
    var end: Point2 { get }
}

enum LineSegment {
    fileprivate typealias Impl = LineSegmentImpl

    // MARK: SlopeIntercept

    struct SlopeIntercept: Impl {
        let slopeIntercept: Line.SlopeIntercept
        let x0: CGFloat, x1: CGFloat

        var line: Line { .slopeIntercept(slopeIntercept) }
        var start: Point2 { Point2(x0, slopeIntercept.y(x: x0)) }
        var end: Point2 { Point2(x1, slopeIntercept.y(x: x1)) }

        func position(paramT: CGFloat) -> Point2 {
            let t = (0 ... 1).clamp(paramT)
            let xt = x0 + (x1 - x0) * t
            let yt = slopeIntercept.y(x: xt)
            return Point2(xt, yt)
        }

        func paramT(closestTo point: Point2) -> (t: CGFloat, distance: CGFloat) {
            let p = line.projected(from: point)
            if p.x < x0 {
                return (t: 0, distance: start.distance(to: point))
            } else if p.x > x1 {
                return (t: 1, distance: end.distance(to: point))
            }
            return (t: (p.x - x0) / (x1 - x0), p.distance(to: point))
        }
    }

    // MARK: Vertical

    struct Vertical: Impl {
        let vertical: Line.Vertical
        let y0: CGFloat, y1: CGFloat

        var line: Line { .vertical(vertical) }
        var start: Point2 { Point2(vertical.x, y0) }
        var end: Point2 { Point2(vertical.x, y1) }

        func position(paramT: CGFloat) -> Point2 {
            let t = (0 ... 1).clamp(paramT)
            let yt = y0 + (y1 - y0) * t
            return Point2(vertical.x, yt)
        }

        func paramT(closestTo point: Point2) -> (t: CGFloat, distance: CGFloat) {
            let p = line.projected(from: point)
            if p.y < y0 {
                return (t: 0, distance: start.distance(to: point))
            } else if p.y > y1 {
                return (t: 1, distance: end.distance(to: point))
            }
            return (t: (p.y - y0) / (y1 - y0), p.distance(to: point))
        }
    }

    case slopeIntercept(SlopeIntercept)
    case vertical(Vertical)

    init(p0: Point2, p1: Point2) {
        let line = Line(p0: p0, p1: p1)
        switch line {
        case let .slopeIntercept(slopeIntercept):
            var x0 = p0.x, x1 = p1.x
            if x0 > x1 {
                swap(&x0, &x1)
            }
            self = .slopeIntercept(.init(slopeIntercept: slopeIntercept, x0: x0, x1: x1))
        case let .vertical(vertical):
            var y0 = p0.y, y1 = p1.y
            if y0 > y1 {
                swap(&y0, &y1)
            }
            self = .vertical(.init(vertical: vertical, y0: y0, y1: y1))
        }
    }
}

extension LineSegment: LineSegmentImpl {
    var line: Line { impl.line }
    var start: Point2 { impl.start }
    var end: Point2 { impl.end }

    func position(paramT: CGFloat) -> Point2 { impl.position(paramT: paramT) }
    func paramT(closestTo point: Point2) -> (t: CGFloat, distance: CGFloat) { impl.paramT(closestTo: point) }

    var length: CGFloat { start.distance(to: end) }

    private var impl: Impl {
        switch self {
        case let .slopeIntercept(si): si
        case let .vertical(v): v
        }
    }
}

// MARK: - PolyLine

struct PolyLine {
    let points: [Point2]
    let segments: [LineSegment]
    let length: CGFloat

    var count: Int { points.count }

    init(points: [Point2]) {
        let segments = points.enumerated().compactMap { pair -> LineSegment?in
            let (i, p0) = pair
            guard i + 1 < points.count else { return nil }
            let p1 = points[i + 1]
            return LineSegment(p0: p0, p1: p1)
        }
        let length = segments.reduce(0.0) { prev, curr in prev + curr.length }

        self.points = points
        self.segments = segments
        self.length = length
    }
}

// MARK: parametrization

extension PolyLine: Parametrizable, InverseParametrizable {
    struct SegmentParam {
        let i: Int // segment index
        let t: CGFloat // segment param t
    }

    func segmentParam(paramT: CGFloat) -> SegmentParam {
        let t = (0 ... 1).clamp(paramT)
        if t == 0 {
            return SegmentParam(i: 0, t: 0)
        } else if t == 1 {
            return SegmentParam(i: segments.count - 1, t: 1)
        }
        let target = length * t
        var cumulated: CGFloat = 0
        for (i, s) in segments.enumerated() {
            let curr = cumulated + s.length
            let diff = curr - target
            if diff > 0 {
                return SegmentParam(i: i, t: diff / s.length)
            }
            cumulated = curr
        }
        return SegmentParam(i: segments.count - 1, t: 1)
    }

    func paramT(segmentParam param: SegmentParam) -> CGFloat {
        var cumulated: CGFloat = 0
        for (i, s) in segments.enumerated() {
            if i == param.i {
                let p = s.position(paramT: param.t)
                cumulated += p.distance(to: s.start)
                break
            }
            cumulated += s.length
        }
        return (0 ... 1).clamp(cumulated / length)
    }

    func position(segmentParam param: SegmentParam) -> Point2 { segments[param.i].position(paramT: param.t) }

    func position(paramT: CGFloat) -> Point2 { position(segmentParam: segmentParam(paramT: paramT)) }

    func segmentParam(closestTo point: Point2) -> (param: SegmentParam, distance: CGFloat) {
        segments.enumerated()
            .map { i, s in
                let (t, distance) = s.paramT(closestTo: point)
                return (param: SegmentParam(i: i, t: t), distance: distance)
            }
            .min(by: { $0.distance < $1.distance })!
    }

    func paramT(closestTo point: Point2) -> (t: CGFloat, distance: CGFloat) {
        let (segmentParam, distance) = segmentParam(closestTo: point)
        return (t: paramT(segmentParam: segmentParam), distance: distance)
    }
}
