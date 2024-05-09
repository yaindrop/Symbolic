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

// MARK: - axis, align, position

enum Axis: CaseIterable {
    case horizontal, vertical
}

extension Axis: CustomStringConvertible {
    var description: String {
        switch self {
        case .horizontal: "horizontal"
        case .vertical: "vertical"
        }
    }
}

enum EdgeAlign: CaseIterable {
    case start, center, end
}

extension EdgeAlign: CustomStringConvertible {
    var description: String {
        switch self {
        case .start: "start"
        case .center: "center"
        case .end: "end"
        }
    }
}

enum AlignPosition {
    case topLeading, topCenter, topTrailing
    case centerLeading, center, centerTrailing
    case bottomLeading, bottomCenter, bottomTrailing

    var isLeading: Bool { [.topLeading, .centerLeading, .bottomLeading].contains(self) }
    var isHorizontalCenter: Bool { [.topCenter, .center, .bottomCenter].contains(self) }
    var isTrailing: Bool { [.topTrailing, .centerTrailing, .bottomTrailing].contains(self) }
    var horizontal: EdgeAlign { isLeading ? .start : isTrailing ? .end : .center }

    var isTop: Bool { [.topLeading, .topCenter, .topTrailing].contains(self) }
    var isVerticalCenter: Bool { [.centerLeading, .center, .centerTrailing].contains(self) }
    var isBottom: Bool { [.bottomLeading, .bottomCenter, .bottomTrailing].contains(self) }
    var vertical: EdgeAlign { isTop ? .start : isBottom ? .end : .center }

    init(horizontal: EdgeAlign, vertical: EdgeAlign) {
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

struct AtAlignPositionModifier: ViewModifier {
    let position: AlignPosition

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
    func atAlignPosition(_ position: AlignPosition) -> some View {
        modifier(AtAlignPositionModifier(position: position))
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

    func modifier(_ modifier: (some ViewModifier)?) -> some View {
        self.if(modifier != nil, then: { $0.modifier(modifier!) })
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

extension DragGesture.Value {
    var offset: Vector2 { .init(translation) }

    var inertia: Vector2 { Vector2(predictedEndTranslation) - offset }
}

// MARK: - read size

struct ViewSizeReader: ViewModifier {
    let onChange: (CGSize) -> Void

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.size, initial: true) {
                        onChange(geometry.size)
                    }
                }
            }
    }
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        modifier(ViewSizeReader(onChange: onChange))
    }
}
