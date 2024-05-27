import Foundation
import SwiftUI

// MARK: - ManagedScrollViewModel

class ManagedScrollViewModel: ObservableObject {
    @Published fileprivate(set) var offset: Scalar = 0
    let coordinateSpaceName = UUID().uuidString

    var scrolled: Bool { offset > 0 }
}

// MARK: - ScrollOffsetKey

private struct ScrollOffsetKey: PreferenceKey {
    typealias Value = Scalar
    static var defaultValue: Scalar = .zero
    static func reduce(value: inout Value, nextValue: () -> Value) { value += nextValue() }
}

// MARK: - ScrollOffsetReaderModifier

private struct ScrollOffsetReaderModifier: ViewModifier {
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

// MARK: - ScrollOffsetSetterModifier

private struct ScrollOffsetSetterModifier: ViewModifier {
    @ObservedObject var model: ManagedScrollViewModel

    func body(content: Content) -> some View {
        content.coordinateSpace(name: model.coordinateSpaceName)
            .onPreferenceChange(ScrollOffsetKey.self) { value in withAnimation { model.offset = value } }
    }
}

private extension View {
    func scrollOffsetReader(model: ManagedScrollViewModel) -> some View {
        modifier(ScrollOffsetReaderModifier(model: model))
    }

    func scrollOffsetSetter(model: ManagedScrollViewModel) -> some View {
        modifier(ScrollOffsetSetterModifier(model: model))
    }
}

// MARK: - ManagedScrollView

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
