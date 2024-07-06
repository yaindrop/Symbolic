import Foundation

// MARK: - LineSegment

enum LineSegment {
    // MARK: SlopeIntercept

    struct SlopeIntercept {
        let slopeIntercept: Line.SlopeIntercept
        let x0: Scalar, x1: Scalar
        var xRange: ClosedRange<Scalar> { .init(start: x0, end: x1) }
    }

    // MARK: Vertical

    struct Vertical {
        let vertical: Line.Vertical
        let y0: Scalar, y1: Scalar
        var yRange: ClosedRange<Scalar> { .init(start: y0, end: y1) }
    }

    case slopeIntercept(SlopeIntercept)
    case vertical(Vertical)

    static func vertical(x: Scalar, y0: Scalar, y1: Scalar) -> Self { .vertical(.init(vertical: .init(x: x), y0: y0, y1: y1)) }
    static func horizontal(y: Scalar, x0: Scalar, x1: Scalar) -> Self { .slopeIntercept(.init(slopeIntercept: .init(m: 0, b: y), x0: x0, x1: x1)) }

    init(p0: Point2, p1: Point2) {
        switch Line(p0: p0, p1: p1) {
        case let .slopeIntercept(si): self = .slopeIntercept(.init(slopeIntercept: si, x0: p0.x, x1: p1.x))
        case let .vertical(v): self = .vertical(.init(vertical: v, y0: p0.y, y1: p1.y))
        }
    }
}

// MARK: Impl

private protocol LineSegmentImpl: Equatable, Parametrizable, InverseParametrizable {
    var line: Line { get }
    var start: Point2 { get }
    var end: Point2 { get }
    var length: Scalar { get }
}

extension LineSegment.SlopeIntercept: LineSegmentImpl {
    var line: Line { .slopeIntercept(slopeIntercept) }
    var start: Point2 { slopeIntercept.point(x: x0) }
    var end: Point2 { slopeIntercept.point(x: x1) }
    var length: Scalar { start.distance(to: end) }
}

extension LineSegment.Vertical: LineSegmentImpl {
    var line: Line { .vertical(vertical) }
    var start: Point2 { vertical.point(y: y0) }
    var end: Point2 { vertical.point(y: y1) }
    var length: Scalar { abs(y0 - y1) }
}

extension LineSegment: LineSegmentImpl {
    fileprivate typealias Impl = any LineSegmentImpl

    var line: Line { impl.line }
    var start: Point2 { impl.start }
    var end: Point2 { impl.end }
    var length: Scalar { impl.length }

    private var impl: Impl {
        switch self {
        case let .slopeIntercept(si): si
        case let .vertical(v): v
        }
    }
}

// MARK: Parametrizable

extension LineSegment.SlopeIntercept: Parametrizable {
    func position(paramT: Scalar) -> Point2 {
        let t = (0 ... 1).clamp(paramT)
        let xt = lerp(from: x0, to: x1, at: t)
        let yt = slopeIntercept.y(x: xt)
        return Point2(xt, yt)
    }
}

extension LineSegment.Vertical: Parametrizable {
    func position(paramT: Scalar) -> Point2 {
        let t = (0 ... 1).clamp(paramT)
        let yt = lerp(from: y0, to: y1, at: t)
        return Point2(vertical.x, yt)
    }
}

extension LineSegment: Parametrizable {
    func position(paramT: Scalar) -> Point2 { impl.position(paramT: paramT) }
}

// MARK: InverseParametrizable

extension LineSegment.SlopeIntercept: InverseParametrizable {
    func paramT(closestTo point: Point2) -> (t: Scalar, distance: Scalar) {
        var p = line.projected(from: point)
        let x = xRange.clamp(p.x)
        p = Point2(x, slopeIntercept.y(x: x))
        return (t: (x - x0) / (x1 - x0), p.distance(to: point))
    }
}

extension LineSegment.Vertical: InverseParametrizable {
    func paramT(closestTo point: Point2) -> (t: Scalar, distance: Scalar) {
        var p = line.projected(from: point)
        let y = yRange.clamp(p.y)
        p = Point2(vertical.x, y)
        return (t: (y - y0) / (y1 - y0), p.distance(to: point))
    }
}

extension LineSegment: InverseParametrizable {
    func paramT(closestTo point: Point2) -> (t: Scalar, distance: Scalar) { impl.paramT(closestTo: point) }
}

extension CGRect {
    var left: LineSegment { .vertical(x: minX, y0: minY, y1: maxY) }
    var right: LineSegment { .vertical(x: maxX, y0: minY, y1: maxY) }
    var top: LineSegment { .horizontal(y: minY, x0: minX, x1: maxX) }
    var bottom: LineSegment { .horizontal(y: maxY, x0: minX, x1: maxX) }
}

extension Line {
    func intersection(with segment: LineSegment) -> Point2? {
        guard let p = intersection(with: segment.line) else { return nil }
        switch segment {
        case let .slopeIntercept(segment):
            return segment.xRange.contains(p.x) ? p : nil
        case let .vertical(segment):
            return segment.yRange.contains(p.y) ? p : nil
        }
    }

    func segment(in rect: CGRect) -> LineSegment? {
        let edges = [rect.left, rect.top, rect.right, rect.bottom]
        let intersections = edges.compactMap { intersection(with: $0) }
        guard intersections.count == 2 else { return nil }
        return .init(p0: intersections[0], p1: intersections[1])
    }
}

// MARK: - Polyline

struct Polyline {
    let points: [Point2]
    let segments: [LineSegment]
    let length: Scalar

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
        let t: Scalar // segment param t
    }

    func segmentParam(paramT: Scalar) -> SegmentParam {
        let t = (0 ... 1).clamp(paramT)
        if t == 0 {
            return SegmentParam(i: 0, t: 0)
        } else if t == 1 {
            return SegmentParam(i: segments.count - 1, t: 1)
        }
        let target = length * t
        var cumulated: Scalar = 0
        for (i, s) in segments.enumerated() {
            let curr = cumulated + s.length
            if curr > target {
                return SegmentParam(i: i, t: (target - cumulated) / s.length)
            }
            cumulated = curr
        }
        return SegmentParam(i: segments.count - 1, t: 1)
    }

    func position(segmentParam param: SegmentParam) -> Point2 { segments[param.i].position(paramT: param.t) }

    func position(paramT: Scalar) -> Point2 { position(segmentParam: segmentParam(paramT: paramT)) }
}

// MARK: InverseParametrizable

extension Polyline: InverseParametrizable {
    func segmentParam(closestTo point: Point2) -> (param: SegmentParam, distance: Scalar) {
        segments.enumerated()
            .map { i, s in
                let (t, distance) = s.paramT(closestTo: point)
                return (param: SegmentParam(i: i, t: t), distance: distance)
            }
            .min(by: { $0.distance < $1.distance })!
    }

    func paramT(segmentParam param: SegmentParam) -> Scalar {
        var cumulated: Scalar = 0
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

    func paramT(closestTo point: Point2) -> (t: Scalar, distance: Scalar) {
        let (segmentParam, distance) = segmentParam(closestTo: point)
        return (t: paramT(segmentParam: segmentParam), distance: distance)
    }
}

// MARK: approximate inverse parametrization for tessellated path

extension Polyline {
    func approxPathParamT(segmentParam param: SegmentParam) -> Scalar {
        var cumulated = Scalar(param.i)
        let s = segments[param.i]
        let p = s.position(paramT: param.t)
        cumulated += p.distance(to: s.start) / s.length
        return (0 ... 1).clamp(cumulated / Scalar(segments.count))
    }

    func approxPathParamT(closestTo point: Point2) -> (t: Scalar, distance: Scalar) {
        let (segmentParam, distance) = segmentParam(closestTo: point)
        return (t: approxPathParamT(segmentParam: segmentParam), distance: distance)
    }

    func approxPathParamT(lineParamT t: Scalar) -> (t: Scalar, distance: Scalar) {
        approxPathParamT(closestTo: position(paramT: t))
    }
}
