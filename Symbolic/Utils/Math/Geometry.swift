import Foundation

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

    func clampingOffset(by rect: CGRect) -> Vector2 {
        let offsetMax = maxPoint.offset(to: maxPoint.clamped(by: rect))
        let r = self + offsetMax
        let offsetMin = r.minPoint.offset(to: r.minPoint.clamped(by: rect))
        return offsetMax + offsetMin
    }

    func clamped(by rect: CGRect) -> Self { self + clampingOffset(by: rect) }

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
