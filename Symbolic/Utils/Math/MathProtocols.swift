import CoreGraphics
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

// MARK: - VectorArithmetic

extension Vector2: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= rhs }

    public var magnitudeSquared: Double { dotProduct(self) }
}

func lerp<T: VectorArithmetic>(from: T, to: T, at t: Scalar) -> T {
    from + (to - from).scaled(by: t)
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

extension Vector2: ScalarMultiplicable {
    public static func * (lhs: Self, rhs: Scalar) -> Self { .init(lhs.dx * rhs, lhs.dy * rhs) }
}

extension CGSize: ScalarMultiplicable {
    public static func * (lhs: Self, rhs: Scalar) -> Self { .init(lhs.width * rhs, lhs.height * rhs) }
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

extension CGSize: ScalarDivisable {
    public static func / (lhs: Self, rhs: Scalar) -> Self { .init(lhs.width / rhs, lhs.height / rhs) }
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

extension Scalar {
    var isNearlyInteger: Bool { rounded() ~== self }

    var nearlyInteger: Int? {
        let rounded = rounded()
        guard rounded ~== self else { return nil }
        return Int(rounded)
    }
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

func decimalFormatStyle<Value>(maxFractionLength: Int = 3) -> FloatingPointFormatStyle<Value> {
    FloatingPointFormatStyle<Value>().precision(.fractionLength(0 ... maxFractionLength))
}

extension BinaryFloatingPoint {
    func decimalFormatted(maxFractionLength: Int = 3) -> String {
        formatted(decimalFormatStyle(maxFractionLength: maxFractionLength))
    }
}

protocol ShortDescribable {
    var shortDescription: String { get }
}

extension Scalar {
    var shortDescription: String { "\(decimalFormatted())" }
}

extension Vector2 {
    var shortDescription: String { "(\(dx.decimalFormatted(maxFractionLength: 1)), \(dy.decimalFormatted(maxFractionLength: 1)))" }
}

extension Point2 {
    var shortDescription: String { "(\(x.decimalFormatted(maxFractionLength: 1)), \(y.decimalFormatted(maxFractionLength: 1)))" }
}

extension CGSize {
    var shortDescription: String { "(\(width.decimalFormatted(maxFractionLength: 1)), \(height.decimalFormatted(maxFractionLength: 1)))" }
}

extension CGRect {
    var shortDescription: String { String(format: "(x: %.1f, y: %.1f, w: %.1f, h: %.1f)", minX, minY, width, height) }
}

extension Angle {
    var shortDescription: String { "\(degrees.decimalFormatted())°" }
}
