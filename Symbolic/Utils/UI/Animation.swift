import SwiftUI

// MARK: - AnimatedValueModifier

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
    static let normal: Animation = .default
    static let fast: Animation = .normal.speed(2)
    static let faster: Animation = .normal.speed(4)
    static let fastest: Animation = .normal.speed(6)
}

// MARK: - AnimationPreset

enum AnimationPreset {
    case normal, fast, faster, fastest, custom(Animation)

    var animation: Animation {
        switch self {
        case .normal: .normal
        case .fast: .fast
        case .faster: .faster
        case .fastest: .fastest
        case let .custom(animation): animation
        }
    }
}

extension AnimationPreset: CustomStringConvertible {
    var description: String {
        switch self {
        case .normal: "normal"
        case .fast: "fast"
        case .faster: "faster"
        case .fastest: "fastest"
        case let .custom(animation): animation.description
        }
    }
}

// MARK: - AnimatableReader

struct AnimatableReader<Value: Animatable, Content: View>: View, Animatable {
    var value: Value
    @ViewBuilder let content: (Value) -> Content

    init(_ value: Value, @ViewBuilder _ content: @escaping (Value) -> Content) {
        self.value = value
        self.content = content
    }

    var animatableData: Value.AnimatableData {
        get { value.animatableData }
        set { value.animatableData = newValue }
    }

    var body: some View {
        content(value)
    }
}
