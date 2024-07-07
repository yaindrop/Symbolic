import Foundation

class GridStore: Store {
    @Trackable var gridStack: [Grid] = [.init(kind: .cartesian(.init(interval: 8)))]
}

extension GridStore {
    var grid: Grid { gridStack.first! }

    func snap(_ point: Point2) -> Point2 {
        grid.snap(point)
    }

    func update(grid: Grid) {
        update { $0(\._gridStack, [grid]) }
    }
}
