import SwiftUI

// MARK: - AxisAlign

enum AxisAlign: CaseIterable {
    case start, center, end
}

extension AxisAlign {
    var flipped: Self {
        switch self {
        case .start: .end
        case .center: .center
        case .end: .start
        }
    }
}

extension AxisAlign: CustomStringConvertible {
    var description: String {
        switch self {
        case .start: "start"
        case .center: "center"
        case .end: "end"
        }
    }
}

// MARK: - PlaneInnerAlign

enum PlaneInnerAlign: CaseIterable, SelfIdentifiable {
    case topLeading, topCenter, topTrailing
    case centerLeading, center, centerTrailing
    case bottomLeading, bottomCenter, bottomTrailing
}

extension PlaneInnerAlign {
    var horizontal: AxisAlign {
        switch self {
        case .topLeading, .centerLeading, .bottomLeading: .start
        case .topCenter, .center, .bottomCenter: .center
        case .topTrailing, .centerTrailing, .bottomTrailing: .end
        }
    }

    var vertical: AxisAlign {
        switch self {
        case .topLeading, .topCenter, .topTrailing: .start
        case .centerLeading, .center, .centerTrailing: .center
        case .bottomLeading, .bottomCenter, .bottomTrailing: .end
        }
    }

    var isLeading: Bool { horizontal == .start }
    var isHorizontalCenter: Bool { horizontal == .center }
    var isTrailing: Bool { horizontal == .end }

    var isTop: Bool { vertical == .start }
    var isVerticalCenter: Bool { vertical == .center }
    var isBottom: Bool { vertical == .end }

    var direction: Vector2 {
        Axis.allCases.reduce(into: .zero) {
            switch self[$1] {
            case .start: $0 += .unit(on: $1)
            case .center: $0 += .zero
            case .end: $0 += -.unit(on: $1)
            }
        }
    }

    var unitPoint: UnitPoint {
        switch self {
        case .topLeading: .topLeading
        case .topCenter: .top
        case .topTrailing: .topTrailing
        case .centerLeading: .leading
        case .center: .center
        case .centerTrailing: .trailing
        case .bottomLeading: .bottomLeading
        case .bottomCenter: .bottom
        case .bottomTrailing: .bottomTrailing
        }
    }

    subscript(axis: Axis) -> AxisAlign {
        switch axis {
        case .horizontal: horizontal
        case .vertical: vertical
        }
    }

    init(horizontal: AxisAlign, vertical: AxisAlign) {
        switch (horizontal, vertical) {
        case (.start, .start): self = .topLeading
        case (.start, .center): self = .centerLeading
        case (.start, .end): self = .bottomLeading
        case (.center, .start): self = .topCenter
        case (.center, .center): self = .center
        case (.center, .end): self = .bottomCenter
        case (.end, .start): self = .topTrailing
        case (.end, .center): self = .centerTrailing
        case (.end, .end): self = .bottomTrailing
        }
    }

    func flipped(axis: Axis) -> Self {
        switch axis {
        case .horizontal: .init(horizontal: horizontal.flipped, vertical: vertical)
        case .vertical: .init(horizontal: horizontal, vertical: vertical.flipped)
        }
    }
}

// MARK: - PlaneOuterAlign

enum AxisOuterAlign: CaseIterable {
    case start, innerStart, center, innerEnd, end
}

extension AxisOuterAlign {
    var flipped: Self {
        switch self {
        case .start: .end
        case .innerStart: .innerEnd
        case .center: .center
        case .innerEnd: .innerStart
        case .end: .start
        }
    }

    var axisAlign: AxisAlign? {
        switch self {
        case .start: .start
        case .center: .center
        case .end: .end
        default: nil
        }
    }

    init(_ align: AxisAlign) {
        switch align {
        case .start: self = .start
        case .center: self = .center
        case .end: self = .end
        }
    }
}

enum PlaneOuterAlign: CaseIterable, SelfIdentifiable {
    case topLeading, topInnerLeading, topCenter, topInnerTrailing, topTrailing
    case innerTopLeading, innerTopTrailing
    case centerLeading, centerTrailing
    case innerBottomLeading, innerBottomTrailing
    case bottomLeading, bottomInnerLeading, bottomCenter, bottomInnerTrailing, bottomTrailing
}

extension PlaneOuterAlign {
    var horizontal: AxisOuterAlign {
        switch self {
        case .topLeading, .innerTopLeading, .centerLeading, .innerBottomLeading, .bottomLeading: .start
        case .topInnerLeading, .bottomInnerLeading: .innerStart
        case .topCenter, .bottomCenter: .center
        case .topInnerTrailing, .bottomInnerTrailing: .innerEnd
        case .topTrailing, .innerTopTrailing, .centerTrailing, .innerBottomTrailing, .bottomTrailing: .end
        }
    }

    var vertical: AxisOuterAlign {
        switch self {
        case .topLeading, .topInnerLeading, .topCenter, .topInnerTrailing, .topTrailing: .start
        case .innerTopLeading, .innerTopTrailing: .innerStart
        case .centerLeading, .centerTrailing: .center
        case .innerBottomLeading, .innerBottomTrailing: .innerEnd
        case .bottomLeading, .bottomInnerLeading, .bottomCenter, .bottomInnerTrailing, .bottomTrailing: .end
        }
    }

    var isLeading: Bool { horizontal == .start }
    var isHorizontalCenter: Bool { horizontal == .center }
    var isTrailing: Bool { horizontal == .end }

    var isTop: Bool { vertical == .start }
    var isVerticalCenter: Bool { vertical == .center }
    var isBottom: Bool { vertical == .end }

    var innerAlign: PlaneInnerAlign {
        switch self {
        case .topLeading, .topInnerLeading, .innerTopLeading: .topLeading
        case .topCenter: .topCenter
        case .topInnerTrailing, .topTrailing, .innerTopTrailing: .topTrailing
        case .centerLeading: .centerLeading
        case .centerTrailing: .centerTrailing
        case .innerBottomLeading, .bottomLeading, .bottomInnerLeading: .bottomLeading
        case .bottomCenter: .bottomCenter
        case .innerBottomTrailing, .bottomInnerTrailing, .bottomTrailing: .bottomTrailing
        }
    }

    var direction: Vector2 {
        switch self {
        case .topLeading: -.unitXY
        case .topInnerLeading, .topCenter, .topInnerTrailing: -.unitY
        case .topTrailing: .unitX - .unitY
        case .innerTopLeading, .centerLeading, .innerBottomLeading: -.unitX
        case .innerTopTrailing, .centerTrailing, .innerBottomTrailing: .unitX
        case .bottomLeading: -.unitX + .unitY
        case .bottomInnerLeading, .bottomCenter, .bottomInnerTrailing: .unitY
        case .bottomTrailing: .unitXY
        }
    }

    init?(horizontal: AxisOuterAlign, vertical: AxisOuterAlign) {
        switch (horizontal, vertical) {
        case (.start, .start): self = .topLeading
        case (.start, .innerStart): self = .innerTopLeading
        case (.start, .center): self = .centerLeading
        case (.start, .innerEnd): self = .innerBottomLeading
        case (.start, .end): self = .bottomLeading
        case (.innerStart, .start): self = .topInnerLeading
        case (.innerStart, .end): self = .bottomInnerLeading
        case (.center, .start): self = .topCenter
        case (.center, .end): self = .bottomCenter
        case (.innerEnd, .start): self = .topInnerTrailing
        case (.innerEnd, .end): self = .bottomInnerTrailing
        case (.end, .start): self = .topTrailing
        case (.end, .innerStart): self = .innerTopTrailing
        case (.end, .center): self = .centerTrailing
        case (.end, .innerEnd): self = .innerBottomTrailing
        case (.end, .end): self = .bottomTrailing
        default: return nil
        }
    }

    func flipped(axis: Axis) -> Self {
        switch axis {
        case .horizontal: .init(horizontal: horizontal.flipped, vertical: vertical)!
        case .vertical: .init(horizontal: horizontal, vertical: vertical.flipped)!
        }
    }
}

// MARK: - rect align

extension CGRect {
    static func keyPath(on axis: Axis, align: AxisAlign) -> KeyPath<Self, Scalar> {
        switch axis {
        case .horizontal:
            switch align {
            case .start: \.minX
            case .center: \.midX
            case .end: \.maxX
            }
        case .vertical:
            switch align {
            case .start: \.minY
            case .center: \.midY
            case .end: \.maxY
            }
        }
    }

    func alignedPoint(at align: PlaneInnerAlign) -> Point2 {
        var x: Scalar {
            switch align[.horizontal] {
            case .start: minX
            case .center: midX
            case .end: maxX
            }
        }
        var y: Scalar {
            switch align[.vertical] {
            case .start: minY
            case .center: midY
            case .end: maxY
            }
        }
        return .init(x: x, y: y)
    }

    func alignedPoint(at align: PlaneInnerAlign, gap: CGSize) -> Point2 {
        alignedPoint(at: align) + align.direction.elementWiseProduct(.init(gap))
    }

    func alignedBox(at align: PlaneInnerAlign, size: CGSize) -> CGRect {
        .init(center: alignedPoint(at: align) + align.direction.elementWiseProduct(.init(size)) / 2, size: size)
    }

    func alignedBox(at align: PlaneInnerAlign, size: CGSize, gap: CGSize) -> CGRect {
        alignedBox(at: align, size: size) + align.direction.elementWiseProduct(.init(gap))
    }

    func alignedBox(at align: PlaneOuterAlign, size: CGSize) -> CGRect {
        alignedBox(at: align.innerAlign, size: size) + align.direction.elementWiseProduct(.init(size))
    }

    func alignedBox(at align: PlaneOuterAlign, size: CGSize, gap: CGSize) -> CGRect {
        alignedBox(at: align, size: size) + align.direction.elementWiseProduct(.init(gap))
    }

    func nearestInnerAlign(of point: Point2, isCorner: Bool = false) -> PlaneInnerAlign {
        if isCorner {
            let xAlign: AxisAlign = point.x < midX ? .start : .end
            let yAlign: AxisAlign = point.y < midY ? .start : .end
            return .init(horizontal: xAlign, vertical: yAlign)
        } else {
            let xAlign: AxisAlign = point.x < (minX + midX) / 2 ? .start : point.x < (midX + maxX) / 2 ? .center : .end
            let yAlign: AxisAlign = point.y < (minY + midY) / 2 ? .start : point.y < (midY + maxY) / 2 ? .center : .end
            return .init(horizontal: xAlign, vertical: yAlign)
        }
    }
}

extension Point2 {
    func alignedPoint(at align: PlaneInnerAlign, gap: CGSize) -> Point2 {
        CGRect(origin: self, size: .zero).alignedPoint(at: align, gap: gap)
    }

    func alignedBox(at align: PlaneInnerAlign, size: CGSize) -> CGRect {
        CGRect(origin: self, size: .zero).alignedBox(at: align, size: size)
    }

    func alignedBox(at align: PlaneInnerAlign, size: CGSize, gap: CGSize) -> CGRect {
        CGRect(origin: self, size: .zero).alignedBox(at: align, size: size, gap: gap)
    }
}

// MARK: - AxisAlignModifier

struct AxisAlignModifier: ViewModifier {
    let axis: Axis, align: AxisAlign

    func body(content: Content) -> some View {
        switch axis {
        case .horizontal:
            HStack(spacing: 0) { wrapper(content) }
        case .vertical:
            VStack(spacing: 0) { wrapper(content) }
        }
    }

    @ViewBuilder func wrapper(_ content: Content) -> some View {
        if align != .start { Spacer(minLength: 0) }
        content
        if align != .end { Spacer(minLength: 0) }
    }
}

extension View {
    func aligned(axis: Axis, _ align: AxisAlign) -> some View {
        modifier(AxisAlignModifier(axis: axis, align: align))
    }
}

// MARK: - InnerAlignModifier

struct InnerAlignModifier: ViewModifier {
    let align: PlaneInnerAlign

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            if !align.isLeading { Spacer(minLength: 0) }
            VStack(spacing: 0) {
                if !align.isTop { Spacer(minLength: 0) }
                content
                if !align.isBottom { Spacer(minLength: 0) }
            }
            if !align.isTrailing { Spacer(minLength: 0) }
        }
    }
}

extension View {
    func innerAligned(_ align: PlaneInnerAlign) -> some View {
        modifier(InnerAlignModifier(align: align))
    }
}
