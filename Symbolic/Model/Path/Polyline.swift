import Foundation

// MARK: - Polyline

struct Polyline: Equatable {
    let points: [Point2]
    let segments: [LineSegment]
    let length: Scalar

    var count: Int { points.count }

    init(points: [Point2]) {
        let segments = points.enumerated().compactMap { pair -> LineSegment? in
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

// MARK: Transformable

extension Polyline: Transformable {
    func applying(_ t: CGAffineTransform) -> Self {
        .init(points: points.map { $0.applying(t) })
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
                let t = s.length != 0 ? (target - cumulated) / s.length : 0
                return SegmentParam(i: i, t: t)
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
        guard length != 0 else { return 0 }
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
        guard length != 0 else { return 0 }
        cumulated += p.distance(to: s.start) / s.length
        guard !segments.isEmpty else { return 0 }
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

// MARK: SUPathAppendable

extension Polyline: SUPathAppendable {
    func append(to path: inout SUPath) {
        guard points.count > 1 else { return }
        path.move(to: points[0])
        for i in 1 ..< points.count {
            path.addLine(to: points[i])
        }
    }
}
