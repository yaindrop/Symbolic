import SwiftUI

// MARK: - AnimatedValueModifier

struct AnimatedValueModifier<Value: Equatable>: ViewModifier {
    @Binding var value: Value
    let from: Value
    let to: Value
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .onAppear { withAnimation(animation) { value = to } }
            .onDisappear { withAnimation(animation) { value = from } }
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

struct AnimatableReader<Value: Animatable, Content: View>: View, Animatable, TracedView, UniqueEquatable {
    var value: Value
    let content: (Value) -> Content

    init(_ value: Value, @ViewBuilder _ content: @escaping (Value) -> Content) {
        self.value = value
        self.content = content
    }

    var animatableData: Value.AnimatableData {
        get { value.animatableData }
        set { value.animatableData = newValue }
    }

    var body: some View { trace {
        content(value)
    } }
}

// MARK: - AnimatablePair

extension AnimatablePair {
    var tuple: (First, Second) { (first, second) }
}

extension View {
    func animatableReader<Value: Animatable & Equatable>(_ value: Value, onValue: @escaping (Value) -> Void) -> some View {
        background {
            AnimatableReader(value) { value in
                Color.clear
                    .onChange(of: value, initial: true) {
                        onValue(value)
                    }
            }
        }
    }
}
