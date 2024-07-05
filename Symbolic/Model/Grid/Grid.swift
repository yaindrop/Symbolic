import Foundation

protocol Snappable {
    func snap(_ point: Point2) -> Point2
}

extension Snappable {
    func snapped(_ point: Point2) -> Bool {
        point == snap(point)
    }
}

enum Grid: Equatable {
    struct Cartesian: Equatable {
        let cellSize: Scalar
    }

    case cartesian(Cartesian)
}

// MARK: - Snappable

extension Grid.Cartesian: Snappable {
    func snap(_ point: Point2) -> Point2 {
        let x = round(point.x / cellSize) * cellSize
        let y = round(point.y / cellSize) * cellSize
        return .init(x: x, y: y)
    }
}

extension Grid: Snappable {
    func snap(_ point: Point2) -> Point2 {
        switch self {
        case let .cartesian(cartesian): cartesian.snap(point)
        }
    }
}
