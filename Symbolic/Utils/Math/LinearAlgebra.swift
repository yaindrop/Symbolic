import CoreGraphics
import Foundation
import SwiftUI

public typealias Scalar = CGFloat
public typealias Vector2 = CGVector
public typealias Point2 = CGPoint

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

// MARK: - CGAffineTransform

extension CGAffineTransform: TriviallyCloneable {
    var translation: Vector2 { Vector2(tx, ty) }

    func centered(at anchor: Point2, _ transform: (Self) -> Self) -> Self {
        translatedBy(Vector2(anchor))
            .apply(transform)
            .translatedBy(-Vector2(anchor))
    }

    func translatedBy(_ vector: Vector2) -> Self { translatedBy(x: vector.dx, y: vector.dy) }

    func scaledBy(_ scale: Scalar) -> Self { scaledBy(x: scale, y: scale) }

    init(translation vector: Vector2) { self.init(translationX: vector.dx, y: vector.dy) }

    init(scale: Scalar) { self.init(scaleX: scale, y: scale) }
}
