import SwiftUI

struct ParallelLineSet {
    var interval: Scalar
    var angle: Angle

    init(interval: Scalar, angle: Angle) {
        self.interval = interval
        self.angle = angle
    }

    init(line: Line) {
        switch line {
        case let .vertical(line): interval = line.x
        case let .slopeIntercept(line): interval = line.b * cos(line.angle.radians)
        }
        angle = line.angle
    }
}

extension ParallelLineSet {
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
        guard interval != 0 else { return 0 }
        if angle.isRight {
            let i = p.x / interval
            return Int(i.rounded())
        } else {
            let b = Line(point: p, angle: angle).intersection(with: .yAxis)!.y
            let i = b * cos(angle.radians) / interval
            return Int(i.rounded())
        }
    }

    func range(in rect: CGRect) -> ClosedRange<Int> {
        let extrema = [rect.minPoint, rect.minXmaxYPoint, rect.maxXminYPoint, rect.maxPoint].map { index(closestTo: $0) }
        return .init(start: extrema.min()!, end: extrema.max()!)
    }
}

struct ConcentricCircleSet {
    var interval: Scalar
}

// MARK: - GridView

enum GridViewType {
    case background
    case preview
}

enum GridLineType: CaseIterable {
    case normal
    case principal
    case axis
}

struct GridView: View, TracedView {
    let grid: Grid
    let viewport: SizedViewportInfo
    let color: Color
    let type: GridViewType

    var body: some View { trace {
        content
    }}
}

extension GridView {
    @ViewBuilder var content: some View {
        let lineSets = lineSets
        ZStack {
            lines(lineSets: lineSets)
            labels(lineSets: lineSets)
        }
    }

    var targetCellSize: Scalar { 24 }

    var worldRect: CGRect { viewport.worldRect }

    var cellSize: Scalar {
        switch grid {
        case let .cartesian(grid): grid.interval
        case let .isometric(grid): grid.interval
        case .radial: 1
        }
    }

    var adjustedCellSize: Scalar {
        let targetSizeInWorld = (Vector2.unitX * targetCellSize).applying(viewport.viewToWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / cellSize))))
        return cellSize * adjustedRatio
    }

    var lineSets: [ParallelLineSet] {
        let adjustedCellSize = adjustedCellSize
        switch grid {
        case .cartesian:
            return [.init(line: .vertical(x: adjustedCellSize)), .init(line: .horizontal(y: adjustedCellSize))]
        case let .isometric(grid):
            let b = adjustedCellSize * (tan(grid.angle0.radians) + tan(-grid.angle1.radians))
            return [.init(line: .init(b: b, angle: grid.angle0)), .init(line: .init(b: b, angle: grid.angle1)), .init(line: .vertical(x: adjustedCellSize))]
        case .radial: return []
        }
    }

    func lineType(index: Int) -> GridLineType {
        if index == 0 {
            .axis
        } else if index % 2 == 0 {
            .principal
        } else {
            .normal
        }
    }

    func path(type: GridLineType, lineSets: [ParallelLineSet]) -> SUPath {
        .init { path in
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
            for lineSet in lineSets {
                draw(lineSet: lineSet)
            }
        }
    }

    @ViewBuilder func lines(lineSets: [ParallelLineSet]) -> some View {
        ForEach(GridLineType.allCases, id: \.self) { type in
            let lines = path(type: type, lineSets: lineSets)
            switch type {
            case .normal: lines.stroke(color.opacity(0.3), style: .init(lineWidth: 0.5))
            case .principal: lines.stroke(color.opacity(0.5), style: .init(lineWidth: 1))
            case .axis: lines.stroke(color.opacity(0.8), style: .init(lineWidth: 2))
            }
        }
    }

    @ViewBuilder func labels(lineSets: [ParallelLineSet]) -> some View {
        let verticalLineSet = lineSets.first { $0.angle.isRight }
        let horizontalLineSet = lineSets.first { $0.angle.isFull }
        Group {
            if let verticalLineSet {
                let verticalLines = verticalLineSet.range(in: worldRect)
                    .filter { lineType(index: $0) != .normal }
                    .compactMap { verticalLineSet.line(at: $0).vertical }
                ForEach(verticalLines, id: \.x) {
                    GridVerticalLabel(line: $0, viewport: viewport, hasSafeArea: type == .background)
                }
            }
            if let horizontalLineSet {
                let horizontalLines = horizontalLineSet.range(in: worldRect)
                    .filter { lineType(index: $0) != .normal }
                    .compactMap { horizontalLineSet.line(at: $0).slopeIntercept }
                ForEach(horizontalLines, id: \.b) {
                    GridHorizontalLabel(line: $0, viewport: viewport)
                }
            }
        }
        .foregroundColor(color)
    }
}

// MARK: - GridVerticalLabel

private struct GridVerticalLabel: View, TracedView {
    let line: Line.Vertical
    let viewport: SizedViewportInfo
    let hasSafeArea: Bool

    @State private var size: CGSize = .zero

    var body: some View { trace {
        content
    }}
}

private extension GridVerticalLabel {
    var x: Scalar { line.x }

    var xInView: Scalar { Point2(x, 0).applying(viewport.worldToView).x }

    var text: String { "\(Int(x))" }

    var rotated: Bool { x >= 1000 || x <= -1000 }

    var padding: Scalar { 3 }

    var safeAreaPadding: Scalar { hasSafeArea ? 12 : 0 }

    var offset: Vector2 {
        if rotated {
            let width = size.width / sqrt(2) + size.height
            return .init(width / 2 + padding, -width / 2 - padding - safeAreaPadding)
        } else {
            return .init(size.width / 2 + padding, -size.height / 2 - padding - safeAreaPadding)
        }
    }

    @ViewBuilder var content: some View {
        Text(text)
            .font(.caption2)
            .sizeReader { size = $0 }
            .rotationEffect(rotated ? .degrees(-45) : .zero)
            .position(.init(xInView, viewport.size.height))
            .offset(.init(offset))
    }
}

// MARK: - GridHorizontalLabel

private struct GridHorizontalLabel: View, TracedView {
    let line: Line.SlopeIntercept
    let viewport: SizedViewportInfo

    @State private var size: CGSize = .zero

    var body: some View { trace {
        content
    } }
}

private extension GridHorizontalLabel {
    var y: Scalar { line.b }

    var yInView: Scalar { Point2(0, y).applying(viewport.worldToView).y }

    var text: String { "\(Int(y))" }

    var padding: Scalar { 3 }

    var offset: Vector2 {
        .init(size.width / 2 + padding, size.height / 2 + padding)
    }

    @ViewBuilder var content: some View {
        Text(text)
            .font(.caption2)
            .sizeReader { size = $0 }
            .position(.init(0, yInView))
            .offset(.init(offset))
    }
}
