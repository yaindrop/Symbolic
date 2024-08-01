import SwiftUI

struct ParallelLineSet {
    var interval: Scalar
    var angle: Angle

    init(interval: Scalar, angle: Angle) {
        self.interval = interval
        self.angle = angle
    }

    static func vertical(interval: Scalar) -> Self {
        .init(interval: interval, angle: .radians(.pi / 2))
    }

    static func horizontal(interval: Scalar) -> Self {
        .init(interval: interval, angle: .radians(0))
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

    func line(closestTo p: Point2) -> Line {
        line(at: index(closestTo: p))
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

    var targetInterval: Scalar { 24 }

    var targetIntervalInWorld: Scalar { Vector2(targetInterval, 0).applying(viewport.viewToWorld).dx }

    var worldRect: CGRect { viewport.worldRect }

    var lineSets: [ParallelLineSet] {
        switch grid.kind {
        case let .cartesian(grid): grid.lineSets(target: targetIntervalInWorld)
        case let .isometric(grid): grid.lineSets(target: targetIntervalInWorld)
        case .radial: []
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
        .foregroundStyle(color)
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

    var text: String { x.decimalFormatted(maxFractionLength: 1) }

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

    var text: String { y.decimalFormatted(maxFractionLength: 1) }

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
