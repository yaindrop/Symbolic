import Foundation
import SwiftUI

// MARK: - PathSegment

fileprivate protocol Tessellatable {
    func tessellated(count: Int) -> Polyline
}

fileprivate protocol PathAppendable {
    func append(to: inout SUPath)
}

fileprivate protocol PathSegmentImpl: Transformable, Parametrizable, Tessellatable, PathAppendable {
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

        func applying(_ t: CGAffineTransform) -> Self { Self(arc: arc.applying(t), from: from.applying(t), to: to.applying(t)) }
    }

    struct Bezier: Impl {
        let bezier: PathEdge.Bezier
        let from: Point2, to: Point2
        var edge: PathEdge { .bezier(bezier) }

        func applying(_ t: CGAffineTransform) -> Self { Self(bezier: bezier.applying(t), from: from.applying(t), to: to.applying(t)) }
    }

    struct Line: Impl {
        let line: PathEdge.Line
        let from: Point2, to: Point2
        var edge: PathEdge { .line(line) }

        func applying(_ t: CGAffineTransform) -> Self { Self(line: line.applying(t), from: from.applying(t), to: to.applying(t)) }
    }

    case arc(Arc)
    case bezier(Bezier)
    case line(Line)

    init(from: Point2, to: Point2, edge: PathEdge) {
        switch edge {
        case let .line(line): self = .line(.init(line: line, from: from, to: to))
        case let .arc(arc): self = .arc(.init(arc: arc, from: from, to: to))
        case let .bezier(bezier): self = .bezier(.init(bezier: bezier, from: from, to: to))
        }
    }
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
        let p0 = Vector2(from), p1 = Vector2(to)
        return Point2(p0 + (p1 - p0) * t)
    }
}

// MARK: Tessellatable

extension PathSegment.Arc: Tessellatable {
    func tessellated(count: Int = 16) -> Polyline {
        let params = params.centerParams
        let points = (0 ... count).map { i -> Point2 in params.position(paramT: CGFloat(i) / CGFloat(count)) }
        return Polyline(points: points)
    }
}

extension PathSegment.Bezier: Tessellatable {
    func tessellated(count: Int = 16) -> Polyline {
        let points = (0 ... count).map { i in position(paramT: CGFloat(i) / CGFloat(count)) }
        return Polyline(points: points)
    }
}

extension PathSegment.Line: Tessellatable {
    func tessellated(count: Int = 16) -> Polyline {
        let points = (0 ... count).map { i in position(paramT: CGFloat(i) / CGFloat(count)) }
        return Polyline(points: points)
    }
}

// MARK: PathAppendable

fileprivate func approxMove(_ path: inout SUPath, to point: Point2) {
    if let p = path.currentPoint, p ~== point {
        return
    }
    path.move(to: point)
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
        approxMove(&path, to: from)
        let params = params.centerParams
        SUPath { $0.addRelativeArc(center: params.center, radius: 1, startAngle: params.startAngle, delta: params.deltaAngle, transform: params.transform) }
            .forEach { appendNonMove($0, to: &path) }
    }
}

extension PathSegment.Bezier: PathAppendable {
    func append(to path: inout SUPath) {
        approxMove(&path, to: from)
        path.addCurve(to: to, control1: bezier.control0, control2: bezier.control1)
    }
}

extension PathSegment.Line: PathAppendable {
    func append(to path: inout SUPath) {
        approxMove(&path, to: from)
        path.addLine(to: to)
    }
}

// MARK: expose PathSegmentImpl

extension PathSegment: PathSegmentImpl {
    private var impl: Impl {
        switch self {
        case let .line(line): line
        case let .arc(arc): arc
        case let .bezier(bezier): bezier
        }
    }

    var from: CGPoint { impl.from }
    var to: CGPoint { impl.to }
    var edge: PathEdge { impl.edge }

    func applying(_ t: CGAffineTransform) -> Self {
        switch self {
        case let .line(l): .line(l.applying(t))
        case let .arc(a): .arc(a.applying(t))
        case let .bezier(b): .bezier(b.applying(t))
        }
    }

    func position(paramT: CGFloat) -> Point2 { impl.position(paramT: paramT) }

    func tessellated(count: Int = 16) -> Polyline { impl.tessellated(count: count) }

    func append(to path: inout SUPath) { impl.append(to: &path) }
}
