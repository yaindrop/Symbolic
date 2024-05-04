import Foundation
import SwiftUI

// MARK: - PathSegment

fileprivate protocol PathSegmentImpl: Transformable, Parametrizable, Tessellatable, InverseParametrizable, PathAppendable, ParamSplittable {
    var from: Point2 { get }
    var to: Point2 { get }
    var edge: PathEdge { get }
}

enum PathSegment {
    fileprivate typealias Impl = PathSegmentImpl
    struct Arc: Impl {
        let arc: PathEdge.Arc
        let from: Point2, to: Point2
        var edge: PathEdge { .arc(arc) }

        var params: EndpointParams {
            EndpointParams(from: from, to: to, radius: arc.radius, rotation: arc.rotation, largeArc: arc.largeArc, sweep: arc.sweep)
        }
    }

    struct Bezier: Impl {
        let bezier: PathEdge.Bezier
        let from: Point2, to: Point2
        var edge: PathEdge { .bezier(bezier) }
    }

    struct Line: Impl {
        let line: PathEdge.Line
        let from: Point2, to: Point2
        var edge: PathEdge { .line(line) }
    }

    case arc(Arc)
    case bezier(Bezier)
    case line(Line)

    func with(edge: PathEdge) -> Self { .init(from: from, to: to, edge: edge) }

    init(from: Point2, to: Point2, edge: PathEdge) {
        switch edge {
        case let .line(line): self = .line(.init(line: line, from: from, to: to))
        case let .arc(arc): self = .arc(.init(arc: arc, from: from, to: to))
        case let .bezier(bezier): self = .bezier(.init(bezier: bezier, from: from, to: to))
        }
    }
}

extension PathSegment: PathSegmentImpl {
    var from: CGPoint { impl.from }
    var to: CGPoint { impl.to }
    var edge: PathEdge { impl.edge }

    private var impl: Impl {
        switch self {
        case let .arc(arc): arc
        case let .bezier(bezier): bezier
        case let .line(line): line
        }
    }

    private func impl(_ transform: (Impl) -> Impl) -> Self {
        switch self {
        case let .arc(a): .arc(transform(a) as! Arc)
        case let .bezier(b): .bezier(transform(b) as! Bezier)
        case let .line(l): .line(transform(l) as! Line)
        }
    }

    private func impl(_ transform: (Impl) -> (Impl, Impl)) -> (Self, Self) {
        switch self {
        case let .arc(a):
            let (a0, a1) = transform(a) as! (Arc, Arc)
            return (.arc(a0), .arc(a1))
        case let .bezier(b):
            let (b0, b1) = transform(b) as! (Bezier, Bezier)
            return (.bezier(b0), .bezier(b1))
        case let .line(l):
            let (l0, l1) = transform(l) as! (Line, Line)
            return (.line(l0), .line(l1))
        }
    }
}

// MARK: Transformable

extension PathSegment.Arc: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(arc: arc.applying(t), from: from.applying(t), to: to.applying(t)) }
}

extension PathSegment.Bezier: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(bezier: bezier.applying(t), from: from.applying(t), to: to.applying(t)) }
}

extension PathSegment.Line: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { .init(line: line.applying(t), from: from.applying(t), to: to.applying(t)) }
}

extension PathSegment: Transformable {
    func applying(_ t: CGAffineTransform) -> Self { impl { $0.applying(t) }}
}

// MARK: Parametrizable

extension PathSegment.Arc: Parametrizable {
    func position(paramT: CGFloat) -> Point2 {
        params.centerParams.position(paramT: paramT)
    }
}

extension PathSegment.Bezier: Parametrizable {
    func position(paramT: CGFloat) -> Point2 {
        let t = (0.0 ... 1.0).clamp(paramT)
        let p0 = Vector2(from), p1 = Vector2(bezier.control0), p2 = Vector2(bezier.control1), p3 = Vector2(to)
        return Point2(pow(1 - t, 3) * p0 + 3 * pow(1 - t, 2) * t * p1 + 3 * (1 - t) * pow(t, 2) * p2 + pow(t, 3) * p3)
    }
}

extension PathSegment.Line: Parametrizable {
    func position(paramT: CGFloat) -> Point2 {
        let t = (0.0 ... 1.0).clamp(paramT)
        return Point2(lerp(from: Vector2(from), to: Vector2(to), at: t))
    }
}

extension PathSegment: Parametrizable {
    func position(paramT: CGFloat) -> Point2 { impl.position(paramT: paramT) }
}

// MARK: Tessellatable

fileprivate let defaultTessellationCount: Int = 64

fileprivate protocol Tessellatable {
    func tessellated(count: Int) -> Polyline
}

extension PathSegment.Arc: Tessellatable {
    func tessellated(count: Int = defaultTessellationCount) -> Polyline {
        let params = params.centerParams
        let points = (0 ... count).map { i -> Point2 in params.position(paramT: CGFloat(i) / CGFloat(count)) }
        return Polyline(points: points)
    }
}

extension PathSegment.Bezier: Tessellatable {
    func tessellated(count: Int = defaultTessellationCount) -> Polyline {
        let points = (0 ... count).map { i in position(paramT: CGFloat(i) / CGFloat(count)) }
        return Polyline(points: points)
    }
}

extension PathSegment.Line: Tessellatable {
    func tessellated(count: Int = defaultTessellationCount) -> Polyline {
        let points = (0 ... count).map { i in position(paramT: CGFloat(i) / CGFloat(count)) }
        return Polyline(points: points)
    }
}

extension PathSegment: Tessellatable {
    func tessellated(count: Int = defaultTessellationCount) -> Polyline { impl.tessellated(count: count) }
}

// MARK: InverseParametrizable

extension PathSegment.Arc: InverseParametrizable {
    func paramT(closestTo p: Point2) -> (t: CGFloat, distance: CGFloat) { tessellated().approxPathParamT(closestTo: p) }
}

extension PathSegment.Bezier: InverseParametrizable {
    func paramT(closestTo p: Point2) -> (t: CGFloat, distance: CGFloat) { tessellated().approxPathParamT(closestTo: p) }
}

extension PathSegment.Line: InverseParametrizable {
    func paramT(closestTo p: Point2) -> (t: CGFloat, distance: CGFloat) { tessellated().approxPathParamT(closestTo: p) }
}

extension PathSegment: InverseParametrizable {
    func paramT(closestTo p: Point2) -> (t: CGFloat, distance: CGFloat) { impl.paramT(closestTo: p) }
}

// MARK: PathAppendable

fileprivate protocol PathAppendable {
    func append(to: inout SUPath)
}

fileprivate func appendNonMove(_ element: SUPath.Element, to path: inout SUPath) {
    switch element {
    case let .curve(to, control1, control2):
        path.addCurve(to: to, control1: control1, control2: control2)
    case let .line(to):
        path.addLine(to: to)
    case let .quadCurve(to, control):
        path.addQuadCurve(to: to, control: control)
    default:
        return
    }
}

extension PathSegment.Arc: PathAppendable {
    func append(to path: inout SUPath) {
        if path.isEmpty { path.move(to: from) }
        let params = params.centerParams
        SUPath { $0.addRelativeArc(center: params.center, radius: 1, startAngle: params.startAngle, delta: params.deltaAngle, transform: params.transform) }
            .forEach { appendNonMove($0, to: &path) }
    }
}

extension PathSegment.Bezier: PathAppendable {
    func append(to path: inout SUPath) {
        if path.isEmpty { path.move(to: from) }
        path.addCurve(to: to, control1: bezier.control0, control2: bezier.control1)
    }
}

extension PathSegment.Line: PathAppendable {
    func append(to path: inout SUPath) {
        if path.isEmpty { path.move(to: from) }
        path.addLine(to: to)
    }
}

extension PathSegment: PathAppendable {
    func append(to path: inout SUPath) { impl.append(to: &path) }
}

// MARK: ParamSplittable

fileprivate protocol ParamSplittable {
    func split(paramT: CGFloat) -> (Self, Self)
    func subsegment(fromT: CGFloat, toT: CGFloat) -> Self
}

extension PathSegment.Arc: ParamSplittable {
    func split(paramT t: CGFloat) -> (Self, Self) {
        let params = self.params.centerParams
        let params0 = params.with(deltaAngle: params.deltaAngle * t)
        let params1 = params.with(startAngle: params.startAngle + params.deltaAngle * t).with(deltaAngle: params.deltaAngle * (1 - t))
        let a0 = params0.endpointParams.segment
        let a1 = params1.endpointParams.segment
        return (a0, a1)
    }

    func subsegment(fromT: CGFloat, toT: CGFloat) -> Self {
        assert((0.0 ... 1.0).contains(fromT) && (0.0 ... 1.0).contains(toT) && fromT < toT)
        let params = self.params.centerParams
        let params0 = params.with(startAngle: params.startAngle + params.deltaAngle * fromT).with(deltaAngle: params.deltaAngle * (toT - fromT))
        return params0.endpointParams.segment
    }
}

extension PathSegment.Bezier: ParamSplittable {
    func split(paramT t: CGFloat) -> (Self, Self) {
        let p0 = Vector2(from), p1 = Vector2(bezier.control0), p2 = Vector2(bezier.control1), p3 = Vector2(to)
        let p01 = lerp(from: p0, to: p1, at: t), p12 = lerp(from: p1, to: p2, at: t), p23 = lerp(from: p2, to: p3, at: t)
        let p012 = lerp(from: p01, to: p12, at: t), p123 = lerp(from: p12, to: p23, at: t)
        let p0123 = lerp(from: p012, to: p123, at: t)
        return (
            .init(bezier: .init(control0: Point2(p01), control1: Point2(p012)), from: from, to: Point2(p0123)),
            .init(bezier: .init(control0: Point2(p123), control1: Point2(p23)), from: Point2(p0123), to: to)
        )
    }

    func subsegment(fromT: CGFloat, toT: CGFloat) -> Self {
        assert((0.0 ... 1.0).contains(fromT) && (0.0 ... 1.0).contains(toT) && fromT < toT)
        let (s0, _) = split(paramT: toT)
        let (_, s1) = s0.split(paramT: fromT / toT)
        return s1
    }
}

extension PathSegment.Line: ParamSplittable {
    func split(paramT t: CGFloat) -> (Self, Self) {
        let pt = Point2(lerp(from: Vector2(from), to: Vector2(to), at: t))
        return (
            .init(line: PathEdge.Line(), from: from, to: pt),
            .init(line: PathEdge.Line(), from: pt, to: to)
        )
    }

    func subsegment(fromT: CGFloat, toT: CGFloat) -> Self {
        let pt0 = Point2(lerp(from: Vector2(from), to: Vector2(to), at: fromT))
        let pt1 = Point2(lerp(from: Vector2(from), to: Vector2(to), at: toT))
        return .init(line: PathEdge.Line(), from: pt0, to: pt1)
    }
}

extension PathSegment: ParamSplittable {
    func split(paramT: CGFloat) -> (PathSegment, PathSegment) { impl { $0.split(paramT: paramT) } }

    func subsegment(fromT: CGFloat, toT: CGFloat) -> PathSegment { impl { $0.subsegment(fromT: fromT, toT: toT) }}
}
