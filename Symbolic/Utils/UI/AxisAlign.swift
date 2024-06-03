import Foundation
import SwiftUI

// MARK: - AxisAlign

enum AxisAlign: CaseIterable {
    case start, center, end
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

enum PlaneInnerAlign: CaseIterable {
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
}

// MARK: - PlaneOuterAlign

enum PlaneOuterAlign: CaseIterable {
    case topLeading, topInnerLeading, topCenter, topInnerTrailing, topTrailing
    case innerTopLeading, innerTopTrailing
    case centerLeading, centerTrailing
    case innerBottomLeading, innerBottomTrailing
    case bottomLeading, bottomInnerLeading, bottomCenter, bottomInnerTrailing, bottomTrailing
}

extension PlaneOuterAlign {
    var horizontal: AxisAlign? {
        switch self {
        case .topLeading, .innerTopLeading, .centerLeading, .innerBottomLeading, .bottomLeading: .start
        case .topCenter, .bottomCenter: .center
        case .topTrailing, .innerTopTrailing, .centerTrailing, .innerBottomTrailing, .bottomTrailing: .end
        default: nil
        }
    }

    var vertical: AxisAlign? {
        switch self {
        case .topLeading, .topInnerLeading, .topCenter, .topInnerTrailing, .topTrailing: .start
        case .centerLeading, .centerTrailing: .center
        case .bottomLeading, .bottomInnerLeading, .bottomCenter, .bottomInnerTrailing, .bottomTrailing: .end
        default: nil
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
}

// MARK: - rect align

extension CGRect {
    func alignedPoint(at align: PlaneInnerAlign) -> Point2 {
        switch align {
        case .topLeading: minPoint
        case .topCenter: .init(midX, minY)
        case .topTrailing: .init(maxX, minY)
        case .centerLeading: .init(minX, midY)
        case .center: midPoint
        case .centerTrailing: .init(maxX, midY)
        case .bottomLeading: .init(minX, maxY)
        case .bottomCenter: .init(midX, maxY)
        case .bottomTrailing: maxPoint
        }
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
}

// MARK: - InnerAlignModifier

struct InnerAlignModifier: ViewModifier {
    let position: PlaneInnerAlign

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            if !position.isLeading { Spacer(minLength: 0) }
            VStack(spacing: 0) {
                if !position.isTop { Spacer(minLength: 0) }
                content
                if !position.isBottom { Spacer(minLength: 0) }
            }
            if !position.isTrailing { Spacer(minLength: 0) }
        }
    }
}

extension View {
    func innerAligned(_ position: PlaneInnerAlign) -> some View {
        modifier(InnerAlignModifier(position: position))
    }
}
