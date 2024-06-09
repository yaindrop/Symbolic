import SwiftUI

struct AnimatedValue<Value: Equatable, Content: View>: View {
    @State var value: Value
    let from: Value
    let to: Value
    let animation: Animation
    let content: (Value) -> Content

    var body: some View {
        content(value)
            .animation(animation, value: value)
            .onAppear { value = to }
            .onDisappear { value = from }
    }

    init(from: Value, to: Value, _ animation: Animation, content: @escaping (Value) -> Content) {
        value = from
        self.from = from
        self.to = to
        self.animation = animation
        self.content = content
    }
}

extension Animation {
    var fast: Animation { speed(5) }

    static let fast: Animation = .default.fast
}

public func withFastAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(animation?.fast, body)
}
