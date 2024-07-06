import SwiftUI

struct ParallelLineSet {
    var interval: Scalar
    var angle: Angle

    func line(at i: Int) -> Line {
        if angle.isRight {
            let x = Scalar(i) * interval
            return .vertical(x: x)
        } else {
            let b = Scalar(i) * interval / cos(angle.radians)
            return .init(b: b, angle: angle)
        }
    }

    func index(closestTo p: Point2) -> Int {
        if angle.isRight {
            let i = p.x / interval
            return Int(i.rounded())
        } else {
            let b = Line(point: p, angle: angle).intersection(with: .yAxis)!.y
            let i = b / interval * cos(angle.radians)
            return Int(i.rounded())
        }
    }

    func range(in rect: CGRect) -> ClosedRange<Int> {
        let extrema = [rect.minPoint, rect.minXmaxYPoint, rect.maxXminYPoint, rect.maxPoint].map { index(closestTo: $0) }
        print("dbg", self, rect, extrema)
        return .init(start: extrema.min()!, end: extrema.max()!)
    }
}

struct ConcentricCircleSet {
    var interval: Scalar
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

    func lineType(index: Int) -> CartesianGridLineType {
        if index == 0 {
            .axis
        } else if index % 2 == 0 {
            .principal
        } else {
            .normal
        }
    }

    func path(type: CartesianGridLineType) -> SUPath {
        let cellSize = adjustedCellSize
        let horizontalSet = ParallelLineSet(interval: cellSize, angle: .degrees(15))
        let horizontalSet2 = ParallelLineSet(interval: cellSize, angle: .degrees(-45))
        let verticalSet = ParallelLineSet(interval: cellSize * sqrt(2), angle: .radians(.pi / 2))
        return .init { path in
            func draw(segment: LineSegment) {
                path.move(to: segment.start.applying(viewport.worldToView))
                path.addLine(to: segment.end.applying(viewport.worldToView))
            }
            func draw(lineSet: ParallelLineSet) {
                for i in lineSet.range(in: worldRect) {
                    guard lineType(index: i) == type else { continue }
                    let line = lineSet.line(at: i)
                    let segment = line.segment(in: worldRect)
                    guard let segment else { continue }
                    draw(segment: segment)
                }
            }
            draw(lineSet: horizontalSet)
            draw(lineSet: horizontalSet2)
            draw(lineSet: verticalSet)
        }
    }

    @ViewBuilder var lines: some View {
        ForEach(CartesianGridLineType.allCases, id: \.self) { type in
            let lines = path(type: type)
            switch type {
            case .normal: lines.stroke(color.opacity(0.3), style: .init(lineWidth: 0.5))
            case .principal: lines.stroke(color.opacity(0.5), style: .init(lineWidth: 1))
            case .axis: lines.stroke(color.opacity(0.8), style: .init(lineWidth: 2))
            }
        }
    }
}
