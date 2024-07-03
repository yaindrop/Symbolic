import SwiftUI

// MARK: - Background

struct Background: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.worldRect }) var worldRect
        @Selected({ global.grid.grid.cellSize }) var cellSize
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private enum GridLineType: CaseIterable {
    case normal
    case principal
    case axis
}

private extension Background {
    var gridLineColor: Color { .red }

    var content: some View {
        ForEach(GridLineType.allCases, id: \.self) { type in
            let path = BackgroundPath(type: type, cellSize: selector.cellSize, worldRect: selector.worldRect)
            switch type {
            case .normal: path.stroke(gridLineColor.opacity(0.3), style: .init(lineWidth: 0.5))
            case .principal: path.stroke(gridLineColor.opacity(0.5), style: .init(lineWidth: 1))
            case .axis: path.stroke(gridLineColor.opacity(0.8), style: .init(lineWidth: 2))
            }
        }
    }
}

// MARK: - BackgroundPath

private struct BackgroundPath: Shape {
    var type: GridLineType
    var cellSize: Scalar
    var worldRect: CGRect

    var animatableData: AnimatablePair<Vector2, Vector2> {
        get { .init(.init(worldRect.center), .init(worldRect.size)) }
        set { worldRect = .init(center: .init(newValue.first), size: .init(newValue.second)) }
    }

    var targetCellSize: Scalar { 24 }

    func viewport(viewSize: CGSize) -> ViewportInfo { .init(viewSize: viewSize, worldRect: worldRect) }

    func adjustedCellSize(viewport: ViewportInfo) -> Scalar {
        let targetSizeInWorld = (Vector2.unitX * targetCellSize).applying(viewport.viewToWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / cellSize))))
        return cellSize * adjustedRatio
    }

    func linePositions(cellSize: Scalar) -> (horizontal: [Scalar], vertical: [Scalar]) {
        let horizontal = Array(stride(from: round(worldRect.minX / cellSize) * cellSize, to: worldRect.maxX, by: cellSize))
        let vertical = Array(stride(from: round(worldRect.minY / cellSize) * cellSize, to: worldRect.maxY, by: cellSize))
        return (horizontal, vertical)
    }

    func path(in rect: CGRect) -> SUPath {
        let viewport = viewport(viewSize: rect.size)
        let cellSize = adjustedCellSize(viewport: viewport)
        let (horizontal, vertical) = linePositions(cellSize: cellSize)
        func gridLineType(_ position: Scalar) -> GridLineType {
            if position / cellSize ~== 0 {
                .axis
            } else if position / cellSize / 2 ~== round(position / cellSize / 2) {
                .principal
            } else {
                .normal
            }
        }
        return .init { path in
            for x in horizontal {
                guard gridLineType(x) == type else { continue }
                let xInView = Point2(x, 0).applying(viewport.worldToView).x
                path.move(to: .init(xInView, 0))
                path.addLine(to: .init(xInView, rect.height))
            }
            for y in vertical {
                guard gridLineType(y) == type else { continue }
                let yInView = Point2(0, y).applying(viewport.worldToView).y
                path.move(to: .init(0, yInView))
                path.addLine(to: .init(rect.width, yInView))
            }
        }
    }
}
