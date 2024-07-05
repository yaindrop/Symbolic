import Foundation

class GridStore: Store {
    @Trackable var gridStack: [Grid] = [.cartesian(.init(cellSize: 8))]
}

extension GridStore {
    var grid: Grid { gridStack.first! }

    func snap(_ point: Point2) -> Point2 {
        grid.snap(point)
    }
}
