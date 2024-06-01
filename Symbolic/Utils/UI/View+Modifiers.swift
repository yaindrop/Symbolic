import Foundation
import SwiftUI

// MARK: - viewSizeReader

extension View {
    func sizeReader(onSize: @escaping (CGSize) -> Void) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.size, initial: true) {
                        onSize(geometry.size)
                    }
            }
        }
    }

    func geometryReader(onGeometry: @escaping (GeometryProxy) -> Void) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .global), initial: true) {
                        onGeometry(geometry)
                    }
            }
        }
    }
}

// MARK: - framePosition

extension View {
    func framePosition(rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height)
            .position(rect.center)
    }
}

extension View {
    @ViewBuilder func clipRounded<S: ShapeStyle>(radius: Scalar, border: S, stroke: StrokeStyle? = nil) -> some View {
        let shape = RoundedRectangle(cornerSize: .init(radius, radius))
        clipShape(shape)
            .if(stroke) {
                $0.overlay(shape.stroke(border, style: $1))
            } else: {
                $0.overlay(shape.stroke(border))
            }
    }

    func clipRounded(radius: Scalar) -> some View {
        clipShape(RoundedRectangle(cornerSize: .init(radius, radius)))
    }

    func clipRounded(leading: Scalar = 0, trailing: Scalar = 0) -> some View {
        clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: leading, bottomLeading: leading, bottomTrailing: trailing, topTrailing: trailing)))
    }

    func clipRounded(top: Scalar = 0, bottom: Scalar = 0) -> some View {
        clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: top, bottomLeading: bottom, bottomTrailing: bottom, topTrailing: top)))
    }

    func clipRounded(topLeading: Scalar = 0, bottomLeading: Scalar = 0, bottomTrailing: Scalar = 0, topTrailing: Scalar = 0) -> some View {
        clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: topLeading, bottomLeading: bottomLeading, bottomTrailing: bottomTrailing, topTrailing: topTrailing)))
    }
}
