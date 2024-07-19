import SwiftUI

// MARK: - PathNode

struct PathNode: Equatable, Codable {
    var position: Point2
    var controlIn: Vector2
    var controlOut: Vector2

    init(position: Point2, controlIn: Vector2 = .zero, controlOut: Vector2 = .zero) {
        self.position = position
        self.controlIn = controlIn
        self.controlOut = controlOut
    }
}

extension PathNode {
    var positionIn: Point2 { position + controlIn }
    var positionOut: Point2 { position + controlOut }
}

extension PathNode: TriviallyCloneable {}

// MARK: CustomStringConvertible

extension PathNode: CustomStringConvertible {
    var description: String {
        "Node(position: \(position), in: \(controlIn), out: \(controlOut)"
    }
}

// MARK: Transformable

extension PathNode: Transformable {
    func applying(_ t: CGAffineTransform) -> Self {
        .init(position: position.applying(t), controlIn: controlIn.applying(t), controlOut: controlOut.applying(t))
    }
}

// MARK: - PathSegment

struct PathSegment: Equatable {
    var from: Point2
    var to: Point2
    var fromControlOut: Vector2
    var toControlIn: Vector2

    init(from: Point2, to: Point2, fromControlOut: Vector2 = .zero, toControlIn: Vector2 = .zero) {
        self.from = from
        self.to = to
        self.fromControlOut = fromControlOut
        self.toControlIn = toControlIn
    }

    init(from: PathNode, to: PathNode) {
        self.from = from.position
        self.to = to.position
        fromControlOut = from.controlOut
        toControlIn = to.controlIn
    }
}

extension PathSegment {
    var fromOut: Point2 { from + fromControlOut }
    var toIn: Point2 { to + toControlIn }

    var isLine: Bool { fromControlOut == .zero && toControlIn == .zero }
}

// MARK: CustomStringConvertible

extension PathSegment: CustomStringConvertible {
    var description: String {
        "Segment(from: \(from), to: \(to), out: \(fromControlOut), in: \(toControlIn)"
    }
}

// MARK: Transformable

extension PathSegment: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(from: from.applying(t), to: to.applying(t), fromControlOut: fromControlOut.applying(t), toControlIn: toControlIn.applying(t)) }
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
            .init(from: from, to: .init(p0123), fromControlOut: p01 - p0, toControlIn: p012 - p0123),
            .init(from: .init(p0123), to: to, fromControlOut: p123 - p0123, toControlIn: p23 - p3)
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
