import Foundation
import SwiftUI

extension UUID: Identifiable {
    public var id: UUID { self }
}

// MARK: - SelfTransformable

protocol SelfTransformable {
    func apply<T>(_ transform: (Self) -> T) -> T
}

extension SelfTransformable {
    func apply<T>(_ transform: (Self) -> T) -> T { transform(self) }
}

// MARK: - Cloneable

protocol Cloneable {
    init(_: Self)
}

extension Cloneable {
    func with(_ transform: (inout Self) -> Void) -> Self {
        var cloned = Self(self)
        transform(&cloned)
        return cloned
    }
}

extension Array: Cloneable {}

// MARK: - ReflectedStringConvertible

public protocol ReflectedStringConvertible: CustomStringConvertible { }

extension ReflectedStringConvertible {
    public var description: String {
        let mirror = Mirror(reflecting: self)
        let propertiesStr = mirror.children.compactMap { label, value in
            guard let label = label else { return nil }
            return "\(label): \(value)"
        }.joined(separator: ", ")
        return "\(mirror.subjectType)(\(propertiesStr))"
    }
}

// MARK: - CornerPosition

enum CornerPosition {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var isTop: Bool { return self == .topLeft || self == .topRight }
    var isBottom: Bool { return self == .bottomLeft || self == .bottomRight }
    var isLeft: Bool { return self == .topLeft || self == .bottomLeft }
    var isRight: Bool { return self == .topRight || self == .bottomRight }
}

struct CornerPositionModifier: ViewModifier {
    let position: CornerPosition

    func body(content: Content) -> some View {
        HStack {
            if position.isRight { Spacer() }
            VStack {
                if position.isBottom { Spacer() }
                content
                if position.isTop { Spacer() }
            }
            if position.isLeft { Spacer() }
        }
    }
}

extension View {
    func atCornerPosition(_ position: CornerPosition) -> some View {
        modifier(CornerPositionModifier(position: position))
    }
}

// MARK: - conditional modifier

extension View {
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
}

// MARK: - ManagedScrollView

class ManagedScrollViewModel: ObservableObject {
    @Published var offset: Scalar = 0
    let coordinateSpaceName = UUID().uuidString

    var scrolled: Bool { offset > 0 }
}

fileprivate struct ScrollOffsetKey: PreferenceKey {
    typealias Value = Scalar
    static var defaultValue: Scalar = .zero
    static func reduce(value: inout Value, nextValue: () -> Value) { value += nextValue() }
}

fileprivate struct ScrollOffsetReaderModifier: ViewModifier {
    @ObservedObject var model: ManagedScrollViewModel

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(key: ScrollOffsetKey.self,
                                       value: -proxy.frame(in: .named(model.coordinateSpaceName)).origin.y)
            }
        )
    }
}

fileprivate struct ScrollOffsetSetterModifier: ViewModifier {
    @ObservedObject var model: ManagedScrollViewModel

    func body(content: Content) -> some View {
        content.coordinateSpace(name: model.coordinateSpaceName)
            .onPreferenceChange(ScrollOffsetKey.self) { value in withAnimation { model.offset = value } }
    }
}

fileprivate extension View {
    func scrollOffsetReader(model: ManagedScrollViewModel) -> some View {
        modifier(ScrollOffsetReaderModifier(model: model))
    }

    func scrollOffsetSetter(model: ManagedScrollViewModel) -> some View {
        modifier(ScrollOffsetSetterModifier(model: model))
    }
}

struct ManagedScrollView<Content: View>: View {
    @ObservedObject var model: ManagedScrollViewModel
    @ViewBuilder let content: (ScrollViewProxy) -> Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content(proxy)
                    .scrollOffsetReader(model: model)
            }
            .scrollOffsetSetter(model: model)
        }
    }
}

// MARK: - default colors

extension Color {
    // MARK: text

    static let lightText = Color(.lightText)
    static let darkText = Color(.darkText)
    static let placeholderText = Color(.placeholderText)

    // MARK: label

    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel = Color(.tertiaryLabel)
    static let quaternaryLabel = Color(.quaternaryLabel)

    // MARK: background

    static let systemBackground = Color(.systemBackground)
    static let secondarySystemBackground = Color(.secondarySystemBackground)
    static let tertiarySystemBackground = Color(.tertiarySystemBackground)

    // MARK: fill

    static let systemFill = Color(.systemFill)
    static let secondarySystemFill = Color(.secondarySystemFill)
    static let tertiarySystemFill = Color(.tertiarySystemFill)
    static let quaternarySystemFill = Color(.quaternarySystemFill)

    // MARK: grouped background

    static let systemGroupedBackground = Color(.systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(.secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground = Color(.tertiarySystemGroupedBackground)

    // MARK: gray

    static let systemGray = Color(.systemGray)
    static let systemGray2 = Color(.systemGray2)
    static let systemGray3 = Color(.systemGray3)
    static let systemGray4 = Color(.systemGray4)
    static let systemGray5 = Color(.systemGray5)
    static let systemGray6 = Color(.systemGray6)

    // MARK: others

    static let separator = Color(.separator)
    static let opaqueSeparator = Color(.opaqueSeparator)
    static let link = Color(.link)

    // MARK: system

    static let systemBlue = Color(.systemBlue)
    static let systemPurple = Color(.systemPurple)
    static let systemGreen = Color(.systemGreen)
    static let systemYellow = Color(.systemYellow)
    static let systemOrange = Color(.systemOrange)
    static let systemPink = Color(.systemPink)
    static let systemRed = Color(.systemRed)
    static let systemTeal = Color(.systemTeal)
    static let systemIndigo = Color(.systemIndigo)
}

extension Color {
    static let invisibleSolid: Color = .white.opacity(1e-3)
}

extension View {
    func invisibleSoildOverlay() -> some View {
        overlay(Color.invisibleSolid)
    }
}

extension Gesture {
    @inlinable public func updating(flag: GestureState<Bool>) -> GestureStateGesture<Self, Bool> {
        updating(flag) { _, state, _ in state = true }
    }
}
