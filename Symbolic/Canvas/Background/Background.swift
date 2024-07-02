import SwiftUI

// MARK: - Background

struct Background: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.info }) var viewportInfo
        @Selected({ global.viewport.store.viewSize }) var viewSize
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
    var targetCellSize: Scalar { 24 }
    var gridLineColor: Color { .red }

    var toView: CGAffineTransform { selector.viewportInfo.worldToView }
    var toWorld: CGAffineTransform { selector.viewportInfo.viewToWorld }

    var adjustedCellSize: Scalar {
        let targetSizeInWorld = (Vector2.unitX * targetCellSize).applying(toWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / selector.cellSize))))
        return selector.cellSize * adjustedRatio
    }

    var linePositions: (horizontal: [Scalar], vertical: [Scalar]) {
        let cellSize = adjustedCellSize
        let horizontal = Array(stride(from: round(selector.worldRect.minX / cellSize) * cellSize, to: selector.worldRect.maxX, by: cellSize))
        let vertical = Array(stride(from: round(selector.worldRect.minY / cellSize) * cellSize, to: selector.worldRect.maxY, by: cellSize))
        return (horizontal, vertical)
    }

    var content: some View {
//        let cellSize = adjustedCellSize
//        let (horizontal, vertical) = linePositions
//        func gridLineType(_ position: Scalar) -> GridLineType {
//            if position / cellSize ~== 0 {
//                .axis
//            } else if position / cellSize / 2 ~== round(position / cellSize / 2) {
//                .principal
//            } else {
//                .normal
//            }
//        }
//        func path(_ type: GridLineType) -> SUPath {
//            SUPath { path in
//                for x in horizontal {
//                    guard gridLineType(x) == type else { continue }
//                    let xInView = Point2(x, 0).applying(toView).x
//                    path.move(to: .init(xInView, 0))
//                    path.addLine(to: .init(xInView, selector.viewSize.height))
//                }
//                for y in vertical {
//                    guard gridLineType(y) == type else { continue }
//                    let yInView = Point2(0, y).applying(toView).y
//                    path.move(to: .init(0, yInView))
//                    path.addLine(to: .init(selector.viewSize.width, yInView))
//                }
//            }
//        }
        func path(_ type: GridLineType) -> some Shape {
            BackgroundPath(cellSize: selector.cellSize, type: type, toWorld: toWorld)
        }
        func styledPath(_ type: GridLineType) -> some View {
            switch type {
            case .normal: path(type).stroke(gridLineColor.opacity(0.3), style: .init(lineWidth: 0.5))
            case .principal: path(type).stroke(gridLineColor.opacity(0.5), style: .init(lineWidth: 1))
            case .axis: path(type).stroke(gridLineColor.opacity(0.8), style: .init(lineWidth: 2))
            }
        }
        return ForEach(Array(zip(GridLineType.allCases.indices, GridLineType.allCases)), id: \.0) { _, type in styledPath(type) }
    }
}

private struct BackgroundPath: Shape {
    var cellSize: Scalar
    var type: GridLineType
    var toWorld: CGAffineTransform

    var targetCellSize: Scalar { 24 }

    var toView: CGAffineTransform { toWorld.inverted() }

    var adjustedCellSize: Scalar {
        let targetSizeInWorld = (Vector2.unitX * targetCellSize).applying(toWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / cellSize))))
        return cellSize * adjustedRatio
    }

    func linePositions(in rect: CGRect) -> (horizontal: [Scalar], vertical: [Scalar]) {
        let worldRect = rect.applying(toWorld)
        let cellSize = adjustedCellSize
        let horizontal = Array(stride(from: round(worldRect.minX / cellSize) * cellSize, to: worldRect.maxX, by: cellSize))
        let vertical = Array(stride(from: round(worldRect.minY / cellSize) * cellSize, to: worldRect.maxY, by: cellSize))
        return (horizontal, vertical)
    }

    func path(in rect: CGRect) -> SUPath {
        let cellSize = adjustedCellSize
        let (horizontal, vertical) = linePositions(in: rect)
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
                let xInView = Point2(x, 0).applying(toView).x
                path.move(to: .init(xInView, 0))
                path.addLine(to: .init(xInView, rect.height))
            }
            for y in vertical {
                guard gridLineType(y) == type else { continue }
                let yInView = Point2(0, y).applying(toView).y
                path.move(to: .init(0, yInView))
                path.addLine(to: .init(rect.width, yInView))
            }
        }
    }

    var animatableData: CGAffineTransform.AnimatableData {
        get { toWorld.animatableData }
        set { toWorld = .init(newValue) }
    }
}

extension CGAffineTransform {
    typealias AnimatableData = AnimatablePair<Double, AnimatablePair<Double, AnimatablePair<Double, AnimatablePair<Double, AnimatablePair<Double, Double>>>>>

    var animatableData: AnimatableData {
        .init(a, .init(b, .init(c, .init(d, .init(tx, ty)))))
    }

    init(_ data: AnimatableData) {
        self.init(data.first, data.second.first, data.second.second.first, data.second.second.second.first, data.second.second.second.second.first, data.second.second.second.second.second)
    }
}
