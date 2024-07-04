import SwiftUI

struct EmptyShape: Shape {
    func path(in _: CGRect) -> SUPath {
        .init()
    }
}

struct GeometryFrameMapper<E: GeometryEffect, Content: View>: View {
    let frame: CGRect
    let effect: E
    @ViewBuilder let content: (CGRect?) -> Content

    @State private var mapped: CGRect?

    var body: some View {
        EmptyShape()
            .geometryReader { mapped = $0.frame(in: .global) }
            .framePosition(rect: frame)
            .modifier(effect)
            .overlay { content(mapped) }
    }
}
