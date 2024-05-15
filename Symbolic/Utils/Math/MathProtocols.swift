import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Parametrizable

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
