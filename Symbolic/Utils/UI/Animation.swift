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
}

extension View {
    func animatedValue<Value: Equatable>(_ value: Binding<Value>, from: Value, to: Value, _ animation: Animation) -> some View {
        modifier(AnimatedValueModifier(value: value, from: from, to: to, animation: animation))
    }
}

extension Animation {
    var fast: Animation { speed(5) }

    static let fast: Animation = .default.fast
}

public func withFastAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(animation?.fast, body)
}
