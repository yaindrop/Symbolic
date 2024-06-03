import Foundation

protocol Snappable {
    func snap(_ point: Point2) -> Point2
}

extension Snappable {
    func snapped(_ point: Point2) -> Bool {
        point == snap(point)
    }
}

struct CartesianGrid: Equatable {
    let cellSize: Scalar

    func snap(_ point: Point2) -> Point2 {
        let x = round(point.x / cellSize) * cellSize
        let y = round(point.y / cellSize) * cellSize
        return .init(x: x, y: y)
    }
}
