import Foundation
import SwiftUI

// MARK: - PathSegment

struct PathSegment: Equatable {
    let edge: PathEdge
    let from: Point2
    let to: Point2

    var control0: Point2 { from + edge.control0 }
    var control1: Point2 { to + edge.control1 }
}

// MARK: Transformable

extension PathSegment: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(edge: edge.applying(t), from: from.applying(t), to: to.applying(t)) }
}

// MARK: Parametrizable

extension PathSegment: Parametrizable {
    func position(paramT: Scalar) -> Point2 {
        let t = (0.0 ... 1.0).clamp(paramT)
        let p0 = Vector2(from), p3 = Vector2(to)
        let p1 = p0 + edge.control0, p2 = p3 + edge.control1
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
        path.addCurve(to: to, control1: control0, control2: control1)
    }
}

// MARK: ParamSplittable

private protocol ParamSplittable {
    func split(paramT: Scalar) -> (Self, Self)
    func subsegment(fromT: Scalar, toT: Scalar) -> Self
}

extension PathSegment: ParamSplittable {
    func split(paramT t: Scalar) -> (Self, Self) {
        if edge.isLine {
            let p0 = Vector2(from), p1 = Vector2(to)
            let pt = lerp(from: p0, to: p1, at: t)
            return (
                .init(edge: .init(), from: from, to: .init(pt)),
                .init(edge: .init(), from: .init(pt), to: to)
            )
        }
        let p0 = Vector2(from), p3 = Vector2(to)
        let p1 = p0 + edge.control0, p2 = p3 + edge.control1
        let p01 = lerp(from: p0, to: p1, at: t), p12 = lerp(from: p1, to: p2, at: t), p23 = lerp(from: p2, to: p3, at: t)
        let p012 = lerp(from: p01, to: p12, at: t), p123 = lerp(from: p12, to: p23, at: t)
        let p0123 = lerp(from: p012, to: p123, at: t)
        return (
            .init(edge: .init(control0: p01 - p0, control1: p012 - p0123), from: from, to: .init(p0123)),
            .init(edge: .init(control0: p123 - p0123, control1: p23 - p3), from: .init(p0123), to: to)
        )
    }

    func subsegment(fromT: Scalar, toT: Scalar) -> Self {
        assert((0.0 ... 1.0).contains(fromT) && (0.0 ... 1.0).contains(toT) && fromT < toT)
        if edge.isLine {
            let p0 = Vector2(from), p1 = Vector2(to)
            let pt0 = lerp(from: p0, to: p1, at: fromT)
            let pt1 = lerp(from: p0, to: p1, at: toT)
            return .init(edge: .init(), from: .init(pt0), to: .init(pt1))
        }
        let (s0, _) = split(paramT: toT)
        let (_, s1) = s0.split(paramT: fromT / toT)
        return s1
    }
}
