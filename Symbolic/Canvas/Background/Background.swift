import SwiftUI

private enum GridLineType: CaseIterable {
    case normal
    case principal
    case axis
}

struct Background: View, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.viewport.info }) var viewportInfo
        @Selected({ global.viewport.store.viewSize }) var viewSize
        @Selected({ global.viewport.worldRect }) var worldRect
        @Selected({ global.grid.grid.cellSize }) var cellSize
    }

    @StateObject var selector = Selector()

    var body: some View {
        setupSelector {
            linePaths
        }
    }

    // MARK: private

    private static let targetCellSize: Scalar = 24
    private static let gridLineColor: Color = .red

    private var toView: CGAffineTransform { selector.viewportInfo.worldToView }
    private var toWorld: CGAffineTransform { selector.viewportInfo.viewToWorld }

    private var adjustedCellSize: Scalar {
        let targetSizeInWorld = (Vector2.unitX * Self.targetCellSize).applying(toWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / selector.cellSize))))
        return selector.cellSize * adjustedRatio
    }

    private var linePositions: (horizontal: [Scalar], vertical: [Scalar]) {
        let cellSize = adjustedCellSize
        let horizontal = Array(stride(from: round(selector.worldRect.minX / cellSize) * cellSize, to: selector.worldRect.maxX, by: cellSize))
        let vertical = Array(stride(from: round(selector.worldRect.minY / cellSize) * cellSize, to: selector.worldRect.maxY, by: cellSize))
        return (horizontal, vertical)
    }

    private var linePaths: some View {
        let cellSize = adjustedCellSize
        let (horizontal, vertical) = linePositions
        func gridLineType(_ position: Scalar) -> GridLineType {
            if position / cellSize ~== 0 {
                .axis
            } else if position / cellSize / 2 ~== round(position / cellSize / 2) {
                .principal
            } else {
                .normal
            }
        }
        func path(_ type: GridLineType) -> SUPath {
            SUPath { path in
                for x in horizontal {
                    guard gridLineType(x) == type else { continue }
                    let xInView = Point2(x, 0).applying(toView).x
                    path.move(to: .init(xInView, 0))
                    path.addLine(to: .init(xInView, selector.viewSize.height))
                }
                for y in vertical {
                    guard gridLineType(y) == type else { continue }
                    let yInView = Point2(0, y).applying(toView).y
                    path.move(to: .init(0, yInView))
                    path.addLine(to: .init(selector.viewSize.width, yInView))
                }
            }
        }
        func styledPath(_ type: GridLineType) -> some View {
            switch type {
            case .normal: path(type).stroke(Self.gridLineColor.opacity(0.3), style: .init(lineWidth: 0.5))
            case .principal: path(type).stroke(Self.gridLineColor.opacity(0.5), style: .init(lineWidth: 1))
            case .axis: path(type).stroke(Self.gridLineColor.opacity(0.8), style: .init(lineWidth: 2))
            }
        }
        return ForEach(Array(zip(GridLineType.allCases.indices, GridLineType.allCases)), id: \.0) { _, type in styledPath(type) }
    }
}
