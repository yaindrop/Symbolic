import SwiftUI

// MARK: - conditional modifier

/// Important: use only when necessary since it alters the view structure
extension View {
    @ViewBuilder func `if`<Value, T: View>(
        _ value: @autoclosure () -> Value?,
        then content: (Self, Value) -> T
    ) -> some View {
        if let value = value() {
            content(self, value)
        } else {
            self
        }
    }

    @ViewBuilder func `if`<Value, Content: View, NilContent: View>(
        _ value: @autoclosure () -> Value?,
        then content: (Self, Value) -> Content,
        else nilContent: (Self) -> NilContent
    ) -> some View {
        if let value = value() {
            content(self, value)
        } else {
            nilContent(self)
        }
    }

    @ViewBuilder func `if`<T: View>(
        _ condition: @autoclosure () -> Bool,
        then content: (Self) -> T
    ) -> some View {
        if condition() {
            content(self)
        } else {
            self
        }
    }

    @ViewBuilder func `if`<TrueContent: View, FalseContent: View>(
        _ condition: @autoclosure () -> Bool,
        then trueContent: (Self) -> TrueContent,
        else falseContent: (Self) -> FalseContent
    ) -> some View {
        if condition() {
            trueContent(self)
        } else {
            falseContent(self)
        }
    }

    func modifier(_ modifier: (some ViewModifier)?) -> some View {
        self.if(modifier != nil, then: { $0.modifier(modifier!) })
    }
}

// MARK: - invisible solid

extension Color {
    static let invisibleSolid: Color = .white.opacity(1e-3)
}

extension View {
    func invisibleSoildOverlay(disabled: Bool = false) -> some View {
        overlay(disabled ? Color.clear : Color.invisibleSolid)
    }
}

// MARK: - geometryReader

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

// MARK: - padding

extension View {
    func padding(size: CGSize) -> some View {
        padding(.horizontal, size.width).padding(.vertical, size.height)
    }
}

// MARK: - frame

extension View {
    func frame(size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }

    func framePosition(rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height)
            .position(rect.center)
    }
}

// MARK: - clipRounded

extension View {
    @ViewBuilder func clipRounded<S: ShapeStyle>(radius: Scalar, border: S, stroke: StrokeStyle? = nil) -> some View {
        let shape = RoundedRectangle(cornerSize: .init(radius, radius))
        clipShape(shape)
            .overlay(shape.stroke(border, style: stroke ?? .init(lineWidth: 1)).allowsHitTesting(false))
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

// MARK: - bind

extension View {
    func bind<Value: Equatable>(_ value: Value, to binding: Binding<Value>) -> some View {
        onChange(of: value, initial: true) {
            if binding.wrappedValue != value {
                binding.wrappedValue = value
            }
        }
    }

    func bind<Value, T: Equatable>(_ value: Value, to binding: Binding<T>, mapper: @escaping (Value) -> T) -> some View {
        onChange(of: mapper(value), initial: true) {
            let value = mapper(value)
            if binding.wrappedValue != value {
                binding.wrappedValue = value
            }
        }
    }
}
