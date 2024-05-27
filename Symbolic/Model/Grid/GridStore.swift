import Foundation

class GridStore: Store {
    @Trackable var grid: CartesianGrid = CartesianGrid(cellSize: 8)

    func snap(_ point: CGPoint) -> CGPoint {
        grid.snap(point)
    }
}
