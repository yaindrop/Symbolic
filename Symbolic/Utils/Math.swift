import CoreGraphics
import Foundation
import SwiftUI

protocol Transformable {
    func applying(_ t: CGAffineTransform) -> Self
}

extension CGFloat {
    var shortDescription: String { String(format: "%.3f", self) }
}

extension ClosedRange {
    func clamp(_ value: Bound) -> Bound {
        return lowerBound > value ? lowerBound : upperBound < value ? upperBound : value
    }
}

// MARK: - Matrix2

struct Matrix2 {
    var a: CGFloat
    var b: CGFloat
    var c: CGFloat
    var d: CGFloat

    var rows: (Vector2, Vector2) { (Vector2(a, b), Vector2(c, d)) }
    var cols: (Vector2, Vector2) { (Vector2(a, c), Vector2(b, d)) }

    init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }

    init(row0: Vector2, row1: Vector2) { self.init(a: row0.dx, b: row0.dy, c: row1.dx, d: row1.dy) }

    init(col0: Vector2, col1: Vector2) { self.init(a: col0.dx, b: col1.dx, c: col0.dy, d: col1.dy) }

    init(_ row0: (CGFloat, CGFloat), _ row1: (CGFloat, CGFloat)) { self.init(row0: Vector2(row0.0, row0.1), row1: Vector2(row1.0, row1.1)) }

    public static func * (lhs: Matrix2, rhs: Vector2) -> Vector2 {
        let rows = lhs.rows
        return Vector2(rows.0.dotProduct(rhs), rows.1.dotProduct(rhs))
    }

    public static func * (lhs: Matrix2, rhs: Matrix2) -> Matrix2 {
        let cols = rhs.cols
        return Matrix2(col0: lhs * cols.0, col1: lhs * cols.1)
    }
}

// MARK: - Vector2

public typealias Vector2 = CGVector

extension Vector2: AdditiveArithmetic, Transformable {
    var shortDescription: String { String(format: "(%.1f, %.1f)", dx, dy) }

    init(_ x: CGFloat, _ y: CGFloat) { self.init(dx: x, dy: y) }

    init(_ point: Point2) { self.init(point.x, point.y) }

    init(_ size: CGSize) { self.init(size.width, size.height) }

    // MARK: vector operator

    public static func + (lhs: Vector2, rhs: Vector2) -> Vector2 { Vector2(lhs.dx + rhs.dx, lhs.dy + rhs.dy) }

    public static func - (lhs: Vector2, rhs: Vector2) -> Vector2 { Vector2(lhs.dx - rhs.dx, lhs.dy - rhs.dy) }

    public static func += (lhs: inout Vector2, rhs: Vector2) { lhs = lhs + rhs }

    public static func -= (lhs: inout Vector2, rhs: Vector2) { lhs = lhs - rhs }

    public static prefix func - (vector: Vector2) -> Vector2 { Vector2(-vector.dx, -vector.dy) }

    // MARK: scalar operator

    public static func * (lhs: Vector2, rhs: CGFloat) -> Vector2 { Vector2(lhs.dx * rhs, lhs.dy * rhs) }

    public static func * (lhs: CGFloat, rhs: Vector2) -> Vector2 { rhs * lhs }

    public static func / (lhs: Vector2, rhs: CGFloat) -> Vector2 { Vector2(lhs.dx / rhs, lhs.dy / rhs) }

    public static func *= (lhs: inout Vector2, rhs: CGFloat) { lhs = lhs * rhs }

    public static func /= (lhs: inout Vector2, rhs: CGFloat) { lhs = lhs / rhs }

    // MARK: geometric operation

    var length: CGFloat { hypot(dx, dy) }

    func dotProduct(_ rhs: Vector2) -> CGFloat { dx * rhs.dx + dy * rhs.dy }

    func crossProduct(_ rhs: Vector2) -> CGFloat { dx * rhs.dy - dy * rhs.dx }

    func radian(_ v: Vector2) -> CGFloat {
        let dot = dotProduct(v)
        let mod = length * v.length
        var rad = acos((-1.0 ... 1.0).clamp(dot / mod))
        if crossProduct(v) < 0 {
            rad = -rad
        }
        return rad
    }

    // MARK: init

    func applying(_ t: CGAffineTransform) -> Self {
        var translationCancelled = t
        translationCancelled.tx = 0
        translationCancelled.ty = 0
        return Self(Point2(self).applying(translationCancelled))
    }
}

// MARK: - Point2

public typealias Point2 = CGPoint

extension Point2 {
    var shortDescription: String { String(format: "(%.1f, %.1f)", x, y) }

    init(_ x: CGFloat, _ y: CGFloat) { self.init(x: x, y: y) }

    init(_ vector: Vector2) { self.init(vector.dx, vector.dy) }

    // MARK: operator

    public static func + (lhs: Point2, rhs: Vector2) -> Point2 { Point2(Vector2(lhs) + rhs) }

    public static func - (lhs: Point2, rhs: Vector2) -> Point2 { Point2(Vector2(lhs) - rhs) }

    public static func += (lhs: inout Point2, rhs: Vector2) { lhs = lhs + rhs }

    public static func -= (lhs: inout Point2, rhs: Vector2) { lhs = lhs - rhs }

    // MARK: geometric operation

    func deltaVector(to point: Point2) -> Vector2 { Vector2(point) - Vector2(self) }

    func distance(to point: Point2) -> CGFloat { deltaVector(to: point).length }
}

// MARK: - CGSize

extension CGSize: Transformable {
    var shortDescription: String { String(format: "(%.1f, %.1f)", width, height) }

    init(_ width: CGFloat, _ height: CGFloat) { self.init(width: width, height: height) }

    func applying(_ t: CGAffineTransform) -> Self {
        let v = CGVector(self).applying(t)
        return Self(width: v.dx, height: v.dy)
    }
}

// MARK: - CGRect

extension CGRect {
    var shortDescription: String { String(format: "(x: %.1f, y: %.1f, w: %.1f, h: %.1f)", minX, minY, width, height) }

    var center: Point2 { Point2(midX, midY) }

    init(_ size: CGSize) { self.init(x: 0, y: 0, width: size.width, height: size.height) }

    init(center: Point2, size: CGSize) { self.init(origin: center - Vector2(size) / 2, size: size) }
}

// MARK: - CGAffineTransform

extension CGAffineTransform {
    var translation: Vector2 { Vector2(tx, ty) }

    init(translation vector: Vector2) { self.init(translationX: vector.dx, y: vector.dy) }

    init(scale: CGFloat) { self.init(scaleX: scale, y: scale) }

    func apply<T>(_ mapper: (Self) -> T) -> T { mapper(self) }

    func centered(at anchor: Point2, mapper: (CGAffineTransform) -> CGAffineTransform) -> CGAffineTransform {
        translatedBy(Vector2(anchor))
            .apply(mapper)
            .translatedBy(-Vector2(anchor))
    }

    func translatedBy(_ vector: Vector2) -> CGAffineTransform { translatedBy(x: vector.dx, y: vector.dy) }

    func scaledBy(_ scale: CGFloat) -> CGAffineTransform { scaledBy(x: scale, y: scale) }
}

extension Angle {
    var shortDescription: String { String(format: "%.3f°", degrees) }
}
