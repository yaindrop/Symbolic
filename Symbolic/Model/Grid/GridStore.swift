import Foundation

class GridStore: Store {
    @Trackable var activeIndex: Int = 0
    @Trackable var gridStack: [Grid] = [.init(kind: .cartesian(.init(interval: 8)))]
}

extension GridStore {
    var active: Grid { gridStack.value(at: activeIndex)! }

    func snap(_ point: Point2) -> Point2 {
        active.snap(point)
    }

    func snapped(_ point: Point2) -> Int? {
        gridStack.firstIndex { $0.snapped(point) }
    }
}

extension GridStore {
    func setActive(_ index: Int) {
        guard gridStack.indices.contains(index) else { return }
        update { $0(\._activeIndex, index) }
    }

    func update(grid: Grid) {
        let i = activeIndex
        guard gridStack.indices.contains(i) else { return }
        update { $0(\._gridStack, gridStack.cloned { $0[i] = grid }) }
    }

    func add() {
        guard gridStack.count < 3 else { return }
        update {
            $0(\._gridStack, gridStack + [.init(kind: .cartesian(.init(interval: 8)))])
            $0(\._activeIndex, gridStack.count - 1)
        }
    }

    func delete() {
        guard gridStack.count > 1 else { return }
        update {
            $0(\._gridStack, gridStack.cloned { $0.remove(at: activeIndex) })
            if activeIndex >= gridStack.count {
                $0(\._activeIndex, gridStack.count - 1)
            }
        }
    }
}
