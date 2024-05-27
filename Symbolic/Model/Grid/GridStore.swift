import Foundation

class GridStore: Store {
    @Trackable var grid: CartesianGrid = .init(cellSize: 8)

    func snap(_ point: CGPoint) -> CGPoint {
        grid.snap(point)
    }
}
