import Foundation
import SwiftUI

import SwiftUI

struct ViewSizeReader: ViewModifier {
    let onChange: (CGSize) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.size) { onChange(geometry.size) }
                }
            )
    }
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        modifier(ViewSizeReader(onChange: onChange))
    }
}

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    @State var offset: Vector2 = Vector2(24, 24)

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: offset.dx)
            VStack(spacing: 0) {
                Spacer().frame(height: offset.dy)
                VStack(spacing: 0) {
                    PanelTitle(name: "Active Path")
                        .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                    scrollView
                }
                .background(.regularMaterial)
                .cornerRadius(12)
//                .readSize { innerSize = $0 }
                .modifier(MultipleGestureModifier(offset, configs: .init(coordinateSpace: .named("Foobar")),
                                                  onDrag: { v, c in
                                                      offset = c + Vector2(v.translation)
                                                  },
                                                  onDragEnd: { v, c in
                                                      offset = c + Vector2(v.translation)
                                                  }))
                Spacer()
            }
            .frame(maxWidth: 320)
            .background { Color.red.opacity(0.1).allowsHitTesting(false) }
            Spacer()
        }
        .coordinateSpace(name: "Foobar")
        .background { Color.blue.opacity(0.1).allowsHitTesting(false) }
    }

    // MARK: private

    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @ViewBuilder private var scrollView: some View {
        if let activePath = activePathModel.pendingActivePath {
            ManagedScrollView(model: scrollViewModel) { proxy in
                Components(activePath: activePath).id(activePath.id)
                    .onChange(of: activePathModel.focusedPart) {
                        guard let id = activePathModel.focusedPart?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}
