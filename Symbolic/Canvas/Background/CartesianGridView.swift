import SwiftUI

enum GridViewType {
    case background
    case preview
}

enum CartesianGridLineType: CaseIterable {
    case normal
    case principal
    case axis
}

// MARK: - CartesianGridView

struct CartesianGridView: View, TracedView {
    let grid: Grid.Cartesian
    let viewport: SizedViewportInfo
    let color: Color
    let type: GridViewType

    var body: some View { trace {
        content
    }}
}

extension CartesianGridView {
    @ViewBuilder var content: some View {
        ZStack {
            lines
            labels
        }
    }

    var targetCellSize: Scalar { 24 }

    var worldRect: CGRect { viewport.worldRect }
    var toWorld: CGAffineTransform { viewport.viewToWorld }
    var toView: CGAffineTransform { viewport.worldToView }

    var adjustedCellSize: Scalar {
        let targetSizeInWorld = (Vector2.unitX * targetCellSize).applying(toWorld).dx
        let adjustedRatio = pow(2, max(0, ceil(log2(targetSizeInWorld / grid.cellSize))))
        return grid.cellSize * adjustedRatio
    }

    var horizontal: [Scalar] {
        let cellSize = adjustedCellSize
        var lower = worldRect.minX / cellSize
        lower = (type == .background ? round(lower) : ceil(lower)) * cellSize
        return .init(stride(from: lower, to: worldRect.maxX, by: cellSize))
    }

    var vertical: [Scalar] {
        let cellSize = adjustedCellSize
        var lower = worldRect.minY / cellSize
        lower = (type == .background ? round(lower) : ceil(lower)) * cellSize
        return .init(stride(from: lower, to: worldRect.maxY, by: cellSize))
    }

    func lineType(cellSize: Scalar, at position: Scalar) -> CartesianGridLineType {
        if position / cellSize ~== 0 {
            .axis
        } else if position / cellSize / 2 ~== round(position / cellSize / 2) {
            .principal
        } else {
            .normal
        }
    }

    func path(type: CartesianGridLineType) -> SUPath {
        let cellSize = adjustedCellSize
        let maxInView = worldRect.maxPoint.applying(toView)
        return .init { path in
            for x in horizontal {
                guard lineType(cellSize: cellSize, at: x) == type else { continue }
                let x = Point2(x, 0).applying(toView).x
                path.move(to: .init(x, 0))
                path.addLine(to: .init(x, maxInView.y))
            }
            for y in vertical {
                guard lineType(cellSize: cellSize, at: y) == type else { continue }
                let y = Point2(0, y).applying(toView).y
                path.move(to: .init(0, y))
                path.addLine(to: .init(maxInView.x, y))
            }
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

    @ViewBuilder var labels: some View {
        let cellSize = adjustedCellSize
        Group {
            ForEach(horizontal.filter { lineType(cellSize: cellSize, at: $0) != .normal }, id: \.self) { x in
                CartesianGridHorizontalLabel(x: x, viewport: viewport, hasSafeArea: type == .background)
            }
            ForEach(vertical.filter { lineType(cellSize: cellSize, at: $0) != .normal }, id: \.self) { y in
                CartesianGridVerticalLabel(y: y, viewport: viewport)
            }
        }
        .foregroundColor(color)
    }
}

// MARK: - CartesianGridHorizontalLabel

private struct CartesianGridHorizontalLabel: View, TracedView {
    let x: Scalar
    let viewport: SizedViewportInfo
    let hasSafeArea: Bool

    @State private var size: CGSize = .zero

    var body: some View { trace {
        content
    }}
}

private extension CartesianGridHorizontalLabel {
    var toView: CGAffineTransform { viewport.worldToView }

    var xInView: Scalar { Point2(x, 0).applying(toView).x }

    var maxInView: Point2 { viewport.worldRect.maxPoint.applying(toView) }

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
            .position(.init(xInView, maxInView.y))
            .offset(.init(offset))
    }
}

// MARK: - CartesianGridVerticalLabel

private struct CartesianGridVerticalLabel: View, TracedView {
    let y: Scalar
    let viewport: SizedViewportInfo

    @State private var size: CGSize = .zero

    var body: some View { trace {
        content
    }}
}

private extension CartesianGridVerticalLabel {
    var toView: CGAffineTransform { viewport.worldToView }

    var yInView: Scalar { Point2(0, y).applying(toView).y }

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
