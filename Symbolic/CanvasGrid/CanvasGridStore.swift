import Foundation

class CanvasGridStore: Store {
    @Trackable var grid: CartesianGrid = CartesianGrid(cellSize: 8)

    func snap(_ point: CGPoint) -> CGPoint {
        grid.snap(point)
    }
}
