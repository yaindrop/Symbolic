import SwiftUI

fileprivate enum GridLineType: CaseIterable {
    case normal
    case principal
    case axis
}

struct Background: View {
    var body: some View {
        GeometryReader {
            canvas(size: $0.size)
        }
    }

    // MARK: private

    @Selected private var viewportInfo = global.viewport.info
    @Selected private var cellSize = global.canvasGrid.grid.cellSize

    private static let targetCellSize: Scalar = 24
    private static let gridLineColor: Color = .red

    private var toView: CGAffineTransform { viewportInfo.worldToView }
    private var toWorld: CGAffineTransform { viewportInfo.viewToWorld }

    private var adjustedCellSize: Scalar {
        let targetSizeInWorld = (Vector2.unitX * Self.targetCellSize).applying(toWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / cellSize))))
        return cellSize * adjustedRatio
    }

    private func lines(size: CGSize) -> (horizontal: [Scalar], vertical: [Scalar]) {
        let cellSize = adjustedCellSize
        let worldRect = viewportInfo.worldRect(viewSize: size)
        let horizontal = Array(stride(from: round(worldRect.minX / cellSize) * cellSize, to: worldRect.maxX, by: cellSize))
        let vertical = Array(stride(from: round(worldRect.minY / cellSize) * cellSize, to: worldRect.maxY, by: cellSize))
        return (horizontal, vertical)
    }

    private func canvas(size: CGSize) -> some View {
        let cellSize = adjustedCellSize
        let (horizontal, vertical) = lines(size: size)
        return Canvas { context, _ in
            func gridLineType(_ position: Scalar) -> GridLineType {
                if position / cellSize ~== 0 {
                    .axis
                } else if position / cellSize / 2 ~== round(position / cellSize / 2) {
                    .principal
                } else {
                    .normal
                }
            }
            for type in GridLineType.allCases {
                let lines = SUPath { path in
                    for x in horizontal {
                        guard gridLineType(x) == type else { continue }
                        let xInView = Point2(x, 0).applying(toView).x
                        path.move(to: .init(xInView, 0))
                        path.addLine(to: .init(xInView, size.height))
                    }
                    for y in vertical {
                        guard gridLineType(y) == type else { continue }
                        let yInView = Point2(0, y).applying(toView).y
                        path.move(to: .init(0, yInView))
                        path.addLine(to: .init(size.width, yInView))
                    }
                }
                switch type {
                case .normal: context.stroke(lines, with: .color(Self.gridLineColor.opacity(0.3)), lineWidth: 0.5)
                case .principal: context.stroke(lines, with: .color(Self.gridLineColor.opacity(0.5)), lineWidth: 1)
                case .axis: context.stroke(lines, with: .color(Self.gridLineColor.opacity(0.8)), lineWidth: 2)
                }
            }
        }
    }
}
