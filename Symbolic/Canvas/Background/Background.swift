import SwiftUI

// MARK: - Background

struct Background: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var viewport
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

private enum BackgroundLineType: CaseIterable {
    case normal
    case principal
    case axis
}

private extension Background {
    var lineColor: Color { .red }

    var content: some View {
        ForEach(BackgroundLineType.allCases, id: \.self) { type in
            let path = BackgroundLines(type: type, cellSize: selector.cellSize, viewport: selector.viewport)
            switch type {
            case .normal: path.stroke(lineColor.opacity(0.3), style: .init(lineWidth: 0.5))
            case .principal: path.stroke(lineColor.opacity(0.5), style: .init(lineWidth: 1))
            case .axis: path.stroke(lineColor.opacity(0.8), style: .init(lineWidth: 2))
            }
        }
    }
}

// MARK: - BackgroundPath

private struct BackgroundLines: Shape {
    var type: BackgroundLineType
    var cellSize: Scalar
    var viewport: SizedViewportInfo

    var animatableData: SizedViewportInfo.AnimatableData {
        get { viewport.animatableData }
        set { viewport.animatableData = newValue }
    }

    var targetCellSize: Scalar { 24 }

    var worldRect: CGRect { viewport.worldRect }
    var toWorld: CGAffineTransform { viewport.viewToWorld }
    var toView: CGAffineTransform { viewport.worldToView }

    var adjustedCellSize: Scalar {
        let targetSizeInWorld = (Vector2.unitX * targetCellSize).applying(toWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / cellSize))))
        return cellSize * adjustedRatio
    }

    func path(in rect: CGRect) -> SUPath {
        let cellSize = adjustedCellSize
        var horizontal: [Scalar] {
            .init(stride(from: round(worldRect.minX / cellSize) * cellSize, to: worldRect.maxX, by: cellSize))
        }
        var vertical: [Scalar] {
            .init(stride(from: round(worldRect.minY / cellSize) * cellSize, to: worldRect.maxY, by: cellSize))
        }
        func lineType(at position: Scalar) -> BackgroundLineType {
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
                guard lineType(at: x) == type else { continue }
                let xInView = Point2(x, 0).applying(toView).x
                path.move(to: .init(xInView, 0))
                path.addLine(to: .init(xInView, rect.height))
            }
            for y in vertical {
                guard lineType(at: y) == type else { continue }
                let yInView = Point2(0, y).applying(toView).y
                path.move(to: .init(0, yInView))
                path.addLine(to: .init(rect.width, yInView))
            }
        }
    }
}
