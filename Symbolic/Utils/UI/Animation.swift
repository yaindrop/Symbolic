import SwiftUI

struct AnimatedValueModifier<Value: Equatable>: ViewModifier {
    @Binding var value: Value
    let from: Value
    let to: Value
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .animation(animation, value: value)
            .onAppear { value = to }
            .onDisappear { value = from }
    }

    init(_ value: Binding<Value>, from: Value, to: Value, _ animation: Animation) {
        _value = value
        self.from = from
        self.to = to
        self.animation = animation
    }
}

extension View {
    func animatedValue<Value: Equatable>(_ value: Binding<Value>, from: Value, to: Value, _ animation: Animation) -> some View {
        modifier(AnimatedValueModifier(value, from: from, to: to, animation))
    }
}

extension Animation {
    var fast: Animation { speed(4) }

    static let fast: Animation = .default.fast
}
