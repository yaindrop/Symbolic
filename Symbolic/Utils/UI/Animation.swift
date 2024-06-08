import SwiftUI

struct AnimatedValue<Value: Equatable>: ViewModifier {
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

public func withFastAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(animation?.speed(5), body)
}
