import CoreGraphics
import Foundation
import SwiftUI

public typealias Scalar = CGFloat
public typealias Vector2 = CGVector
public typealias Point2 = CGPoint

protocol Parametrizable {
    func position(paramT: Scalar) -> Point2
}

protocol InverseParametrizable {
    func paramT(closestTo: Point2) -> (t: Scalar, distance: Scalar)
}

// MARK: - AdditiveArithmetic

extension Vector2: AdditiveArithmetic {
    public static func + (lhs: Self, rhs: Self) -> Self { .init(lhs.dx + rhs.dx, lhs.dy + rhs.dy) }

    public static func - (lhs: Self, rhs: Self) -> Self { .init(lhs.dx - rhs.dx, lhs.dy - rhs.dy) }

    public static prefix func - (vector: Self) -> Self { .zero - vector }
}

// MARK: - ScalarMultiplicable

protocol ScalarMultiplicable {
    static func * (lhs: Self, rhs: Scalar) -> Self
    static func * (lhs: Scalar, rhs: Self) -> Self
    static func *= (lhs: inout Self, rhs: Scalar)
}

extension ScalarMultiplicable {
    public static func * (lhs: Scalar, rhs: Self) -> Self { rhs * lhs }
    public static func *= (lhs: inout Self, rhs: Scalar) { lhs = lhs * rhs }
}

extension Scalar: ScalarMultiplicable {}

extension Vector2: ScalarMultiplicable {
    public static func * (lhs: Self, rhs: Scalar) -> Self { .init(lhs.dx * rhs, lhs.dy * rhs) }
}

func lerp<T: AdditiveArithmetic & ScalarMultiplicable>(from: T, to: T, at t: Scalar) -> T {
    from + (to - from) * t
}

// MARK: - ScalarDivisable

protocol ScalarDivisable {
    static func / (lhs: Self, rhs: Scalar) -> Self
    static func /= (lhs: inout Self, rhs: Scalar)
}

extension ScalarDivisable {
    public static func /= (lhs: inout Self, rhs: Scalar) { lhs = lhs / rhs }
}

extension Vector2: ScalarDivisable {
    public static func / (lhs: Self, rhs: Scalar) -> Self { .init(lhs.dx / rhs, lhs.dy / rhs) }
}

// MARK: - NearlyEquatable

infix operator ~==: ComparisonPrecedence

protocol NearlyEquatable {
    static func ~== (lhs: Self, rhs: Self) -> Bool
}

extension Scalar: NearlyEquatable {
    static let nearlyEqualEpsilon: Scalar = 0.001

    func nearlyEqual(_ n: Self, epsilon: Scalar = Scalar.nearlyEqualEpsilon) -> Bool {
        abs(self - n) < epsilon
    }

    public static func ~== (lhs: Self, rhs: Self) -> Bool { lhs.nearlyEqual(rhs) }
}

extension Vector2: NearlyEquatable {
    func nearlyEqual(_ v: Self, epsilon: Scalar = Scalar.nearlyEqualEpsilon) -> Bool {
        dx.nearlyEqual(v.dx, epsilon: epsilon) && dy.nearlyEqual(v.dy, epsilon: epsilon)
    }

    public static func ~== (lhs: Self, rhs: Self) -> Bool { lhs.nearlyEqual(rhs) }
}

extension Point2: NearlyEquatable {
    func nearlyEqual(_ p: Self, epsilon: Scalar = Scalar.nearlyEqualEpsilon) -> Bool {
        x.nearlyEqual(p.x, epsilon: epsilon) && y.nearlyEqual(p.y, epsilon: epsilon)
    }

    public static func ~== (lhs: Self, rhs: Self) -> Bool { lhs.nearlyEqual(rhs) }
}

// MARK: - Transformable

protocol Transformable {
    func applying(_ t: CGAffineTransform) -> Self
}

extension Point2: Transformable {}

extension CGRect: Transformable {}

extension Vector2: Transformable {
    func applying(_ t: CGAffineTransform) -> Self {
        var translationCancelled = t
        translationCancelled.tx = 0
        translationCancelled.ty = 0
        return .init(Point2(self).applying(translationCancelled))
    }
}

extension CGSize: Transformable {
    func applying(_ t: CGAffineTransform) -> Self {
        let v = Vector2(self).applying(t)
        return .init(width: v.dx, height: v.dy)
    }
}

// MARK: - ShortDescribable

protocol ShortDescribable {
    var shortDescription: String { get }
}

extension Scalar {
    var shortDescription: String { String(format: "%.3f", self) }
}

extension Vector2 {
    var shortDescription: String { String(format: "(%.1f, %.1f)", dx, dy) }
}

extension Point2 {
    var shortDescription: String { String(format: "(%.1f, %.1f)", x, y) }
}

extension CGSize {
    var shortDescription: String { String(format: "(%.1f, %.1f)", width, height) }
}

extension CGRect {
    var shortDescription: String { String(format: "(x: %.1f, y: %.1f, w: %.1f, h: %.1f)", minX, minY, width, height) }
}

extension Angle {
    var shortDescription: String { String(format: "%.3f°", degrees) }
}

// MARK: - ClosedRange

extension ClosedRange {
    func clamp(_ value: Bound) -> Bound {
        return lowerBound > value ? lowerBound : upperBound < value ? upperBound : value
    }

    init(start: Bound, end: Bound) { self = start < end ? start ... end : end ... start }
}

// MARK: - Matrix2

struct Matrix2 {
    var a: Scalar
    var b: Scalar
    var c: Scalar
    var d: Scalar

    var rows: (Vector2, Vector2) { (Vector2(a, b), Vector2(c, d)) }
    var cols: (Vector2, Vector2) { (Vector2(a, c), Vector2(b, d)) }

    public static func * (lhs: Self, rhs: Vector2) -> Vector2 {
        let rows = lhs.rows
        return Vector2(rows.0.dotProduct(rhs), rows.1.dotProduct(rhs))
    }

    public static func * (lhs: Self, rhs: Self) -> Self {
        let cols = rhs.cols
        return .init(col0: lhs * cols.0, col1: lhs * cols.1)
    }

    init(a: Scalar, b: Scalar, c: Scalar, d: Scalar) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }

    init(row0: Vector2, row1: Vector2) { self.init(a: row0.dx, b: row0.dy, c: row1.dx, d: row1.dy) }

    init(col0: Vector2, col1: Vector2) { self.init(a: col0.dx, b: col1.dx, c: col0.dy, d: col1.dy) }

    init(_ row0: (Scalar, Scalar), _ row1: (Scalar, Scalar)) { self.init(row0: Vector2(row0.0, row0.1), row1: Vector2(row1.0, row1.1)) }
}

// MARK: - Vector2

extension Vector2 {
    static let unitX: Self = .init(1, 0)

    static let unitY: Self = .init(0, 1)

    var length: Scalar { hypot(dx, dy) }

    func with(dx: Scalar) -> Self { .init(dx: dx, dy: dy) }

    func with(dy: Scalar) -> Self { .init(dx: dx, dy: dy) }

    // MARK: geometric operation

    func dotProduct(_ rhs: Self) -> Scalar { dx * rhs.dx + dy * rhs.dy }

    func crossProduct(_ rhs: Self) -> Scalar { dx * rhs.dy - dy * rhs.dx }

    func radian(to v: Self) -> Scalar {
        let dot = dotProduct(v)
        let mod = length * v.length
        var rad = acos((-1.0 ... 1.0).clamp(dot / mod))
        if crossProduct(v) < 0 {
            rad = -rad
        }
        return rad
    }

    init(_ x: Scalar, _ y: Scalar) { self.init(dx: x, dy: y) }

    init(_ point: Point2) { self.init(point.x, point.y) }

    init(_ size: CGSize) { self.init(size.width, size.height) }
}

// MARK: - Point2

extension Point2 {
    func with(x: Scalar) -> Self { .init(x: x, y: y) }

    func with(y: Scalar) -> Self { .init(x: x, y: y) }

    // MARK: geometric operation

    func offset(to point: Self) -> Vector2 { Vector2(point) - Vector2(self) }

    func distance(to point: Self) -> Scalar { offset(to: point).length }

    func midPoint(to point: Self) -> Self { .init((Vector2(self) + Vector2(point)) / 2) }

    func clamped(by rect: CGRect) -> Self { .init((rect.minX ... rect.maxX).clamp(x), (rect.minY ... rect.maxY).clamp(y)) }

    // MARK: operator

    public static func + (lhs: Self, rhs: Vector2) -> Self { .init(Vector2(lhs) + rhs) }

    public static func - (lhs: Self, rhs: Vector2) -> Self { .init(Vector2(lhs) - rhs) }

    public static func += (lhs: inout Self, rhs: Vector2) { lhs = lhs + rhs }

    public static func -= (lhs: inout Self, rhs: Vector2) { lhs = lhs - rhs }

    init(_ x: Scalar, _ y: Scalar) { self.init(x: x, y: y) }

    init(_ vector: Vector2) { self.init(vector.dx, vector.dy) }
}

// MARK: - CGSize

extension CGSize {
    var flipped: Self { .init(height, width) }

    func with(width: Scalar) -> Self { .init(width: width, height: height) }

    func with(height: Scalar) -> Self { .init(width: width, height: height) }

    init(_ width: Scalar, _ height: Scalar) { self.init(width: width, height: height) }

    init(squared size: Scalar) { self.init(size, size) }
}

// MARK: - CGRect

extension CGRect {
    var minPoint: Point2 { .init(minX, minY) }
    var midPoint: Point2 { .init(midX, midY) }
    var maxPoint: Point2 { .init(maxX, maxY) }
    var center: Point2 { midPoint }

    func clamped(by rect: CGRect) -> Self {
        let offsetMax = maxPoint.offset(to: maxPoint.clamped(by: rect))
        let r = self + offsetMax
        let offsetMin = r.minPoint.offset(to: r.minPoint.clamped(by: rect))
        return r + offsetMin
    }

    // MARK: operator

    public static func + (lhs: Self, rhs: Vector2) -> Self { .init(origin: lhs.origin + rhs, size: lhs.size) }

    public static func - (lhs: Self, rhs: Vector2) -> Self { lhs + -rhs }

    public static func += (lhs: inout Self, rhs: Vector2) { lhs = lhs + rhs }

    public static func -= (lhs: inout Self, rhs: Vector2) { lhs = lhs - rhs }

    init(_ size: CGSize) { self.init(x: 0, y: 0, width: size.width, height: size.height) }

    init(center: Point2, size: CGSize) { self.init(origin: center - Vector2(size) / 2, size: size) }

    init(from: Point2, to: Point2) {
        let x = Swift.min(from.x, to.x), y = Swift.min(from.y, to.y)
        let w = abs(from.x - to.x), h = abs(from.y - to.y)
        self.init(x: x, y: y, width: w, height: h)
    }
}

// MARK: - CGAffineTransform

extension CGAffineTransform: SelfTransformable {
    var translation: Vector2 { Vector2(tx, ty) }

    func centered(at anchor: Point2, mapper: (Self) -> Self) -> Self {
        translatedBy(Vector2(anchor))
            .apply(mapper)
            .translatedBy(-Vector2(anchor))
    }

    func translatedBy(_ vector: Vector2) -> Self { translatedBy(x: vector.dx, y: vector.dy) }

    func scaledBy(_ scale: Scalar) -> Self { scaledBy(x: scale, y: scale) }

    init(translation vector: Vector2) { self.init(translationX: vector.dx, y: vector.dy) }

    init(scale: Scalar) { self.init(scaleX: scale, y: scale) }
}
