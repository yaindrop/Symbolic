import Foundation
import SwiftUI

import SwiftUI

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

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    @State var origin: Point2 = .init(24, 24)
    @State var viewSize: CGSize = .zero
    @State var panelSize: CGSize = .zero

    func clampPanel() {
        let viewRect = CGRect(viewSize)
        let panelRect = CGRect(origin: origin, size: panelSize)
        origin = panelRect.clamped(by: viewRect).origin
    }

    var gesture: MultipleGestureModifier<Point2> {
        MultipleGestureModifier(origin,
                                configs: .init(coordinateSpace: .named("Foobar")),
                                onDrag: { v, c in
                                    origin = c + Vector2(v.translation)

                                },
                                onDragEnd: { v, c in
                                    origin = c + Vector2(v.translation)
                                    withAnimation { clampPanel() }
                                }
        )
    }

    var body: some View {
        Group {
            panel
                .frame(width: 320)
                .offset(x: origin.x, y: origin.y)
                .readSize { panelSize = $0 }
                .modifier(gesture)
                .atCornerPosition(.topLeading)
        }
        .coordinateSpace(name: "Foobar")
        .readSize { viewSize = $0 }
        .onChange(of: origin) {
            print("origin", origin)
        }
        .onChange(of: viewSize) {
            print("viewSize", viewSize)
            withAnimation { clampPanel() }
        }
        .onChange(of: panelSize) {
            print("panelSize", panelSize)
            withAnimation { clampPanel() }
        }
    }

    // MARK: private

    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Active Path")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
            scrollView
        }
        .background(.regularMaterial)
        .cornerRadius(12)
    }

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
