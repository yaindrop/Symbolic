import Foundation
import SwiftUI

// MARK: - AxisInnerAlign

enum AxisInnerAlign: CaseIterable {
    case start, center, end
}

extension AxisInnerAlign: CustomStringConvertible {
    var description: String {
        switch self {
        case .start: "start"
        case .center: "center"
        case .end: "end"
        }
    }
}

// MARK: - PlaneInnerAlign

enum PlaneInnerAlign {
    case topLeading, topCenter, topTrailing
    case centerLeading, center, centerTrailing
    case bottomLeading, bottomCenter, bottomTrailing

    var isLeading: Bool { [.topLeading, .centerLeading, .bottomLeading].contains(self) }
    var isHorizontalCenter: Bool { [.topCenter, .center, .bottomCenter].contains(self) }
    var isTrailing: Bool { [.topTrailing, .centerTrailing, .bottomTrailing].contains(self) }

    var isTop: Bool { [.topLeading, .topCenter, .topTrailing].contains(self) }
    var isVerticalCenter: Bool { [.centerLeading, .center, .centerTrailing].contains(self) }
    var isBottom: Bool { [.bottomLeading, .bottomCenter, .bottomTrailing].contains(self) }

    func getAxisInnerAlign(in axis: Axis) -> AxisInnerAlign {
        switch axis {
        case .horizontal: isLeading ? .start : isTrailing ? .end : .center
        case .vertical: isTop ? .start : isBottom ? .end : .center
        }
    }

    init(horizontal: AxisInnerAlign, vertical: AxisInnerAlign) {
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
}

// MARK: - AtPlaneAlignModifier

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

enum PlaneOuterAlign: CaseIterable {
    case topLeading, topInnerLeading, topCenter, topInnerTrailing, topTrailing
    case innerTopLeading, innerTopTrailing
    case centerLeading, centerTrailing
    case innerBottomLeading, innerBottomTrailing
    case bottomLeading, bottomInnerLeading, bottomCenter, bottomInnerTrailing, bottomTrailing

    var isLeading: Bool { [.topLeading, .innerTopLeading, .centerLeading, .innerBottomLeading, .bottomLeading].contains(self) }
    var isHorizontalCenter: Bool { [.topCenter, .bottomCenter].contains(self) }
    var isTrailing: Bool { [.topTrailing, .innerTopTrailing, .centerTrailing, .innerBottomTrailing, .bottomTrailing].contains(self) }

    var isTop: Bool { [.topLeading, .topInnerLeading, .topCenter, .topInnerTrailing, .topTrailing].contains(self) }
    var isVerticalCenter: Bool { [.centerLeading, .centerTrailing].contains(self) }
    var isBottom: Bool { [.bottomLeading, .bottomInnerLeading, .bottomCenter, .bottomInnerTrailing, .bottomTrailing].contains(self) }
}

extension PlaneOuterAlign {
    var opposite: Self {
        switch self {
        case .topLeading: .bottomLeading
        case .topInnerLeading: .bottomInnerLeading
        case .topCenter: .bottomCenter
        case .topInnerTrailing: .bottomInnerTrailing
        case .topTrailing: .bottomTrailing
        case .innerTopLeading: .innerTopTrailing
        case .innerTopTrailing: .innerTopLeading
        case .centerLeading: .centerTrailing
        case .centerTrailing: .centerLeading
        case .innerBottomLeading: .innerBottomTrailing
        case .innerBottomTrailing: .innerBottomLeading
        case .bottomLeading: .topLeading
        case .bottomInnerLeading: .topInnerLeading
        case .bottomCenter: .topCenter
        case .bottomInnerTrailing: .topInnerTrailing
        case .bottomTrailing: .topTrailing
        }
    }
}

extension CGRect {
    func alignedBox(at align: PlaneOuterAlign, size: CGSize, gap: Scalar) -> CGRect {
        func point(from align: PlaneInnerAlign, _ gapOffset: Vector2, _ sizeOffset: Vector2) -> Point2 {
            alignedPoint(at: align).offset(by: gapOffset).offset(by: sizeOffset)
        }
        return {
            switch align {
            case .topLeading:
                .init(origin: point(from: .topLeading, .init(-gap, -gap), -.init(size)), size: size)
            case .topInnerLeading:
                .init(origin: point(from: .topLeading, .init(0, -gap), -.init(size).vectorY), size: size)
            case .topCenter:
                .init(center: point(from: .topCenter, .init(0, -gap), -.init(size).vectorY / 2), size: size)
            case .topInnerTrailing:
                .init(origin: point(from: .topTrailing, .init(0, -gap), -.init(size)), size: size)
            case .topTrailing:
                .init(origin: point(from: .topTrailing, .init(gap, -gap), -.init(size).vectorY), size: size)
            case .innerTopLeading:
                .init(origin: point(from: .topLeading, .init(-gap, 0), -.init(size).vectorX), size: size)
            case .innerTopTrailing:
                .init(origin: point(from: .topTrailing, .init(gap, 0), .zero), size: size)
            case .centerLeading:
                .init(center: point(from: .centerLeading, .init(-gap, 0), -.init(size).vectorX / 2), size: size)
            case .centerTrailing:
                .init(center: point(from: .centerTrailing, .init(gap, 0), .init(size).vectorX / 2), size: size)
            case .innerBottomLeading:
                .init(origin: point(from: .bottomLeading, .init(-gap, 0), -.init(size)), size: size)
            case .innerBottomTrailing:
                .init(origin: point(from: .bottomTrailing, .init(gap, 0), -.init(size).vectorY), size: size)
            case .bottomLeading:
                .init(origin: point(from: .bottomLeading, .init(-gap, gap), -.init(size).vectorX), size: size)
            case .bottomInnerLeading:
                .init(origin: point(from: .bottomLeading, .init(0, gap), .zero), size: size)
            case .bottomCenter:
                .init(center: point(from: .bottomCenter, .init(0, gap), .init(size).vectorY / 2), size: size)
            case .bottomInnerTrailing:
                .init(origin: point(from: .bottomTrailing, .init(0, gap), -.init(size).vectorX), size: size)
            case .bottomTrailing:
                .init(origin: point(from: .bottomTrailing, .init(gap, gap), .zero), size: size)
            }
        }()
    }
}
