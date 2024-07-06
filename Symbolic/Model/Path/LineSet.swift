import SwiftUI

protocol LineSet {
    func line(at i: Int) -> Line

    func index(closestTo p: Point2) -> (i: Int, distance: Scalar)
}

extension LineSet {
    func range(in rect: CGRect) -> ClosedRange<Int> {
        let extrema = [rect.minPoint, rect.minXmaxYPoint, rect.maxXminYPoint, rect.maxPoint].map { index(closestTo: $0).i }
        return .init(start: extrema.min()!, end: extrema.max()!)
    }
}

struct VerticalLineSet: LineSet {
    var size: Scalar

    func line(at i: Int) -> Line {
        .vertical(x: Scalar(i) * size)
    }

    func index(closestTo p: Point2) -> (i: Int, distance: Scalar) {
        let i = p.x / size
        let rounded = round(i)
        return (i: Int(rounded), abs(i - rounded))
    }
}

struct HorizontalLineSet: LineSet {
    var size: Scalar

    func line(at i: Int) -> Line {
        .horizontal(y: Scalar(i) * size)
    }

    func index(closestTo p: Point2) -> (i: Int, distance: Scalar) {
        let i = p.y / size
        let rounded = round(i)
        return (i: Int(rounded), abs(i - rounded))
    }
}

// MARK: - CartesianGridView

struct GridView: View, TracedView {
    let grid: Grid.Cartesian
    let viewport: SizedViewportInfo
    let color: Color
    let type: GridViewType

    var body: some View { trace {
        content
    }}
}

extension GridView {
    @ViewBuilder var content: some View {
        ZStack {
            lines
        }
    }

    var targetCellSize: Scalar { 24 }

    var worldRect: CGRect { viewport.worldRect }

    var adjustedCellSize: Scalar {
        let targetSizeInWorld = (Vector2.unitX * targetCellSize).applying(viewport.viewToWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / grid.cellSize))))
        return grid.cellSize * adjustedRatio
    }

//    var horizontal: [Scalar] {
//        let cellSize = adjustedCellSize
//        var lower = worldRect.minX / cellSize
//        lower = (type == .background ? round(lower) : ceil(lower)) * cellSize
//        return .init(stride(from: lower, to: worldRect.maxX, by: cellSize))
//    }
//
//    var vertical: [Scalar] {
//        let cellSize = adjustedCellSize
//        var lower = worldRect.minY / cellSize
//        lower = (type == .background ? round(lower) : ceil(lower)) * cellSize
//        return .init(stride(from: lower, to: worldRect.maxY, by: cellSize))
//    }
//
//    func lineType(cellSize: Scalar, at position: Scalar) -> CartesianGridLineType {
//        if position / cellSize ~== 0 {
//            .axis
//        } else if position / cellSize / 2 ~== round(position / cellSize / 2) {
//            .principal
//        } else {
//            .normal
//        }
//    }

    func path(type _: CartesianGridLineType) -> SUPath {
        let cellSize = adjustedCellSize
        let horizontalSet = HorizontalLineSet(size: cellSize)
        let verticalSet = VerticalLineSet(size: cellSize)
        return .init { path in
//            for x in horizontal {
//                guard lineType(cellSize: cellSize, at: x) == type else { continue }
//                let x = Point2(x, 0).applying(viewport.worldToView).x
//                path.move(to: .init(x, 0))
//                path.addLine(to: .init(x, viewport.size.height))
//            }
//            for y in vertical {
//                guard lineType(cellSize: cellSize, at: y) == type else { continue }
//                let y = Point2(0, y).applying(viewport.worldToView).y
//                path.move(to: .init(0, y))
//                path.addLine(to: .init(viewport.size.width, y))
//            }
            for i in horizontalSet.range(in: worldRect) {
                let line = horizontalSet.line(at: i)
                let segment = line.segment(in: worldRect)
                guard let segment else { continue }
                path.move(to: segment.start.applying(viewport.worldToView))
                path.addLine(to: segment.end.applying(viewport.worldToView))
            }
            for i in verticalSet.range(in: worldRect) {
                let line = verticalSet.line(at: i)
                guard let segment = line.segment(in: worldRect) else { continue }
                path.move(to: segment.start.applying(viewport.worldToView))
                path.addLine(to: segment.end.applying(viewport.worldToView))
            }
        }
    }

    @ViewBuilder var lines: some View {
        path(type: .normal).stroke(color.opacity(0.3), style: .init(lineWidth: 0.5))
//        ForEach(CartesianGridLineType.allCases, id: \.self) { type in
//            let lines = path(type: type)
//            switch type {
//            case .normal: lines.stroke(color.opacity(0.3), style: .init(lineWidth: 0.5))
//            case .principal: lines.stroke(color.opacity(0.5), style: .init(lineWidth: 1))
//            case .axis: lines.stroke(color.opacity(0.8), style: .init(lineWidth: 2))
//            }
//        }
    }
}
