import SwiftUI

// MARK: - CGSize

extension CGSize {
    var flipped: Self { .init(height, width) }

    func with(width: Scalar) -> Self { .init(width: width, height: height) }

    func with(height: Scalar) -> Self { .init(width: width, height: height) }

    public static func + (lhs: Self, rhs: Vector2) -> Self { .init(width: lhs.width + rhs.dx, height: lhs.height + rhs.dy) }

    public static func - (lhs: Self, rhs: Vector2) -> Self { .init(width: lhs.width - rhs.dx, height: lhs.height - rhs.dy) }

    public static func += (lhs: inout Self, rhs: Vector2) { lhs = lhs + rhs }

    public static func -= (lhs: inout Self, rhs: Vector2) { lhs = lhs - rhs }

    static prefix func - (size: Self) -> Self { .init(width: -size.width, height: -size.height) }

    init(_ vector: Vector2) { self.init(vector.dx, vector.dy) }

    init(_ width: Scalar, _ height: Scalar) { self.init(width: width, height: height) }

    init(squared size: Scalar) { self.init(size, size) }
}

// MARK: - CGRect

extension CGRect {
    var minPoint: Point2 { .init(minX, minY) }
    var midPoint: Point2 { .init(midX, midY) }
    var maxPoint: Point2 { .init(maxX, maxY) }
    var center: Point2 { midPoint }
    var minXmaxYPoint: Point2 { .init(minX, maxY) }
    var maxXminYPoint: Point2 { .init(maxX, minY) }

    func clampingOffset(by rect: CGRect) -> Vector2 {
        guard !rect.contains(self) else { return .zero }
        let offsetMax = maxPoint.offset(to: maxPoint.clamped(by: rect))
        let r = self + offsetMax
        let offsetMin = r.minPoint.offset(to: r.minPoint.clamped(by: rect))
        return offsetMax + offsetMin
    }

    func clamped(by rect: CGRect) -> Self {
        guard !rect.contains(self) else { return self }
        return self + clampingOffset(by: rect)
    }

    func inset(by size: Scalar) -> Self {
        let dx = min(width / 2, size)
        let dy = min(height / 2, size)
        return insetBy(dx: dx, dy: dy)
    }

    func outset(by size: Scalar) -> Self { insetBy(dx: -size, dy: -size) }

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

    init?(union rects: [Self]) {
        guard let first = rects.first else { return nil }
        self = rects.dropFirst().reduce(into: first) { bounds, rect in bounds = bounds.union(rect) }
    }

    init?(containing points: [Point2]) {
        self.init(union: points.map { .init(center: $0, size: .zero) })
    }
}

extension Angle {
    var isFull: Bool { (radians / (2 * Scalar.pi)).isNearlyInteger }

    var isStraight: Bool { (radians / (Scalar.pi)).isNearlyInteger && !isFull }

    var isRight: Bool { (radians / (Scalar.pi / 2)).isNearlyInteger && !isFull && !isStraight }
}
