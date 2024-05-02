import Foundation

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
    }

    // MARK: Vertical

    struct Vertical: Impl {
        let vertical: Line.Vertical
        let y0: CGFloat, y1: CGFloat

        var line: Line { .vertical(vertical) }
        var start: Point2 { Point2(vertical.x, y0) }
        var end: Point2 { Point2(vertical.x, y1) }
    }

    case slopeIntercept(SlopeIntercept)
    case vertical(Vertical)

    init(p0: Point2, p1: Point2) {
        switch Line(p0: p0, p1: p1) {
        case let .slopeIntercept(slopeIntercept): self = .slopeIntercept(.init(slopeIntercept: slopeIntercept, x0: p0.x, x1: p1.x))
        case let .vertical(vertical): self = .vertical(.init(vertical: vertical, y0: p0.y, y1: p1.y))
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

// MARK: Parametrizable

extension LineSegment.SlopeIntercept: Parametrizable {
    func position(paramT: CGFloat) -> Point2 {
        let t = (0 ... 1).clamp(paramT)
        let xt = lerp(from: x0, to: x1, at: t)
        let yt = slopeIntercept.y(x: xt)
        return Point2(xt, yt)
    }
}

extension LineSegment.Vertical: Parametrizable {
    func position(paramT: CGFloat) -> Point2 {
        let t = (0 ... 1).clamp(paramT)
        let yt = lerp(from: y0, to: y1, at: t)
        return Point2(vertical.x, yt)
    }
}

// MARK: InverseParametrizable

extension LineSegment.SlopeIntercept: InverseParametrizable {
    func paramT(closestTo point: Point2) -> (t: CGFloat, distance: CGFloat) {
        var p = line.projected(from: point)
        let x = ClosedRange(start: x0, end: x1).clamp(p.x)
        p = CGPoint(x: x, y: slopeIntercept.y(x: x))
        return (t: (x - x0) / (x1 - x0), p.distance(to: point))
    }
}

extension LineSegment.Vertical: InverseParametrizable {
    func paramT(closestTo point: Point2) -> (t: CGFloat, distance: CGFloat) {
        var p = line.projected(from: point)
        let y = ClosedRange(start: y0, end: y1).clamp(p.y)
        p = CGPoint(x: vertical.x, y: y)
        return (t: (y - y0) / (y1 - y0), p.distance(to: point))
    }
}

// MARK: - Polyline

struct Polyline {
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

// MARK: Parametrizable

extension Polyline: Parametrizable {
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

    func position(segmentParam param: SegmentParam) -> Point2 { segments[param.i].position(paramT: param.t) }

    func position(paramT: CGFloat) -> Point2 { position(segmentParam: segmentParam(paramT: paramT)) }
}

// MARK: InverseParametrizable

extension Polyline: InverseParametrizable {
    func segmentParam(closestTo point: Point2) -> (param: SegmentParam, distance: CGFloat) {
        segments.enumerated()
            .map { i, s in
                let (t, distance) = s.paramT(closestTo: point)
                return (param: SegmentParam(i: i, t: t), distance: distance)
            }
            .min(by: { $0.distance < $1.distance })!
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

    func paramT(closestTo point: Point2) -> (t: CGFloat, distance: CGFloat) {
        let (segmentParam, distance) = segmentParam(closestTo: point)
        return (t: paramT(segmentParam: segmentParam), distance: distance)
    }
}

// MARK: approximate inverse parametrization for tessellated path

extension Polyline {
    func approxPathParamT(segmentParam param: SegmentParam) -> CGFloat {
        var cumulated: CGFloat = CGFloat(param.i)
        let s = segments[param.i]
        let p = s.position(paramT: param.t)
        cumulated += p.distance(to: s.start) / s.length
        return (0 ... 1).clamp(cumulated / CGFloat(segments.count))
    }

    func approxPathParamT(closestTo point: Point2) -> (t: CGFloat, distance: CGFloat) {
        let (segmentParam, distance) = segmentParam(closestTo: point)
        return (t: approxPathParamT(segmentParam: segmentParam), distance: distance)
    }
}
