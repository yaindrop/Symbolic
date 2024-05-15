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

// MARK: - PlaneAlign

enum PlaneAlign {
    case topLeading, topCenter, topTrailing
    case centerLeading, center, centerTrailing
    case bottomLeading, bottomCenter, bottomTrailing

    var isLeading: Bool { [.topLeading, .centerLeading, .bottomLeading].contains(self) }
    var isHorizontalCenter: Bool { [.topCenter, .center, .bottomCenter].contains(self) }
    var isTrailing: Bool { [.topTrailing, .centerTrailing, .bottomTrailing].contains(self) }

    var isTop: Bool { [.topLeading, .topCenter, .topTrailing].contains(self) }
    var isVerticalCenter: Bool { [.centerLeading, .center, .centerTrailing].contains(self) }
    var isBottom: Bool { [.bottomLeading, .bottomCenter, .bottomTrailing].contains(self) }

    func getAxisAlign(in axis: Axis) -> AxisAlign {
        switch axis {
        case .horizontal: isLeading ? .start : isTrailing ? .end : .center
        case .vertical: isTop ? .start : isBottom ? .end : .center
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

// MARK: - AtPlaneAlignModifier

struct AtPlaneAlignModifier: ViewModifier {
    let position: PlaneAlign

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
    func atPlaneAlign(_ position: PlaneAlign) -> some View {
        modifier(AtPlaneAlignModifier(position: position))
    }
}
