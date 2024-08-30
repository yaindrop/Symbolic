import SwiftUI

// MARK: - PathNode

struct PathNode: Equatable {
    var position: Point2
    var cubicIn: Vector2
    var cubicOut: Vector2

    init(position: Point2, cubicIn: Vector2 = .zero, cubicOut: Vector2 = .zero) {
        self.position = position
        self.cubicIn = cubicIn
        self.cubicOut = cubicOut
    }
}

extension PathNode {
    var positionIn: Point2 { position + cubicIn }
    var positionOut: Point2 { position + cubicOut }
}

extension PathNode: TriviallyCloneable {}

// MARK: CustomStringConvertible

extension PathNode: CustomStringConvertible {
    var description: String {
        "Node(position: \(position), in: \(cubicIn), out: \(cubicOut))"
    }
}

// MARK: Transformable

extension PathNode: Transformable {
    func applying(_ t: CGAffineTransform) -> Self {
        .init(position: position.applying(t), cubicIn: cubicIn.applying(t), cubicOut: cubicOut.applying(t))
    }
}

// MARK: - PathSegment

struct PathSegment: Equatable {
    var from: Point2
    var to: Point2
    var fromCubicOut: Vector2
    var toCubicIn: Vector2

    init(from: Point2, to: Point2, fromCubicOut: Vector2 = .zero, toCubicIn: Vector2 = .zero) {
        self.from = from
        self.to = to
        self.fromCubicOut = fromCubicOut
        self.toCubicIn = toCubicIn
    }

    init(from: Point2, to: Point2, quadratic: Point2) {
        self.from = from
        self.to = to
        fromCubicOut = from.offset(to: quadratic) * 2 / 3
        toCubicIn = to.offset(to: quadratic) * 2 / 3
    }

    init(from: PathNode, to: PathNode) {
        self.from = from.position
        self.to = to.position
        fromCubicOut = from.cubicOut
        toCubicIn = to.cubicIn
    }
}

extension PathSegment {
    var fromOut: Point2 { from + fromCubicOut }
    var toIn: Point2 { to + toCubicIn }

    var isLine: Bool { fromCubicOut == .zero && toCubicIn == .zero }

    var quadratic: Point2? {
        let c0 = from + fromCubicOut * 3 / 2
        let c1 = to + toCubicIn * 3 / 2
        guard c0 ~= c1 else { return nil }
        return c0
    }

    var toQuradratic: PathSegment {
        let c0 = from + fromCubicOut * 3 / 2
        let c1 = to + toCubicIn * 3 / 2
        let c = c0.midPoint(to: c1)
        return .init(from: from, to: to, quadratic: c)
    }
}

// MARK: CustomStringConvertible

extension PathSegment: CustomStringConvertible {
    var description: String {
        "Segment(from: \(from), to: \(to), out: \(fromCubicOut), in: \(toCubicIn))"
    }
}

// MARK: Transformable

extension PathSegment: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(from: from.applying(t), to: to.applying(t), fromCubicOut: fromCubicOut.applying(t), toCubicIn: toCubicIn.applying(t)) }
}

// MARK: Parametrizable

extension PathSegment: Parametrizable {
    func position(paramT: Scalar) -> Point2 {
        let t = (0.0 ... 1.0).clamp(paramT)
        let p0 = Vector2(from), p3 = Vector2(to)
        let p1 = Vector2(fromOut), p2 = Vector2(toIn)
        return Point2(pow(1 - t, 3) * p0 + 3 * pow(1 - t, 2) * t * p1 + 3 * (1 - t) * pow(t, 2) * p2 + pow(t, 3) * p3)
    }
}

// MARK: Tessellatable

private let defaultTessellationCount: Int = 64

private protocol Tessellatable {
    func tessellated(count: Int) -> Polyline
}

extension PathSegment: Tessellatable {
    func tessellated(count: Int = defaultTessellationCount) -> Polyline {
        assert(count != 0)
        let points = (0 ... count).map { i in position(paramT: Scalar(i) / Scalar(count)) }
        return Polyline(points: points)
    }
}

// MARK: InverseParametrizable

extension PathSegment: InverseParametrizable {
    func paramT(closestTo p: Point2) -> (t: Scalar, distance: Scalar) { tessellated().approxPathParamT(closestTo: p) }
}

// MARK: PathAppendable

extension PathSegment: SUPathAppendable {
    func append(to path: inout SUPath) {
        if path.isEmpty {
            path.move(to: from)
        }
        path.addCurve(to: to, control1: fromOut, control2: toIn)
    }

    var boundingRect: CGRect {
        SUPath { append(to: &$0) }.boundingRect
    }
}

// MARK: ParamSplittable

private protocol ParamSplittable {
    func split(paramT: Scalar) -> (Self, Self)
    func subsegment(fromT: Scalar, toT: Scalar) -> Self
}

extension PathSegment: ParamSplittable {
    func split(paramT t: Scalar) -> (Self, Self) {
        if isLine {
            let p0 = Vector2(from), p1 = Vector2(to)
            let pt = lerp(from: p0, to: p1, at: t)
            return (
                .init(from: from, to: .init(pt)),
                .init(from: .init(pt), to: to)
            )
        }
        let p0 = Vector2(from), p3 = Vector2(to)
        let p1 = Vector2(fromOut), p2 = Vector2(toIn)
        let p01 = lerp(from: p0, to: p1, at: t), p12 = lerp(from: p1, to: p2, at: t), p23 = lerp(from: p2, to: p3, at: t)
        let p012 = lerp(from: p01, to: p12, at: t), p123 = lerp(from: p12, to: p23, at: t)
        let p0123 = lerp(from: p012, to: p123, at: t)
        return (
            .init(from: from, to: .init(p0123), fromCubicOut: p01 - p0, toCubicIn: p012 - p0123),
            .init(from: .init(p0123), to: to, fromCubicOut: p123 - p0123, toCubicIn: p23 - p3)
        )
    }

    func subsegment(fromT: Scalar, toT: Scalar) -> Self {
        assert((0.0 ... 1.0).contains(fromT) && (0.0 ... 1.0).contains(toT) && fromT < toT)
        if isLine {
            let p0 = Vector2(from), p1 = Vector2(to)
            let pt0 = lerp(from: p0, to: p1, at: fromT)
            let pt1 = lerp(from: p0, to: p1, at: toT)
            return .init(from: .init(pt0), to: .init(pt1))
        }
        let (s0, _) = split(paramT: toT)
        let (_, s1) = s0.split(paramT: fromT / toT)
        return s1
    }
}
