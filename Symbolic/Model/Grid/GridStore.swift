import Foundation

class GridStore: Store {
    @Trackable var grid: CartesianGrid = .init(cellSize: 8)

    func snap(_ point: Point2) -> Point2 {
        grid.snap(point)
    }
}
