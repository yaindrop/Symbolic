import Combine
import SwiftUI

// MARK: - CanvasView

struct CanvasView: View, TracedView {
    @State var multipleTouch = MultipleTouchModel()
    @State var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    @State private var longPressPosition: Point2?

    var body: some View { trace {
        content
            .onAppear {
                let setup = CanvasSetup()
                setup.documentLoad()
                setup.pathUpdate()
                setup.multipleTouch(multipleTouch: multipleTouch)

                pressDetector.subscribe()
                setup.multipleTouchPress(multipleTouchPress: multipleTouchPress)
            }
            .onAppear {
                global.panel.register(align: .bottomTrailing) { PathPanel() }
                global.panel.register(align: .bottomLeading) { HistoryPanel() }
                global.panel.register(align: .bottomLeading) { ItemPanel() }
                global.panel.register(align: .topTrailing) { DebugPanel(multipleTouch: multipleTouch, multipleTouchPress: multipleTouchPress) }
            }
            .onAppear {
                global.contextMenu.register(.pathFocusedPart)
                global.contextMenu.register(.focusedPath)
                global.contextMenu.register(.focusedGroup)
                global.contextMenu.register(.selection)
            }
            .onAppear {
                global.document.setDocument(.init(from: fooSvg))
            }
    }}
}

// MARK: private

private extension CanvasView {
    var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }

    // MARK: view builders

    @ViewBuilder var content: some View {
        ZStack {
            canvas
            overlay
        }
        .clipped()
        .edgesIgnoringSafeArea(.all)
        .toolbar(.hidden)
//        .modifier(ToolbarModifier())
    }

    @ViewBuilder var background: some View { trace("background") {
        Background()
    } }

    @ViewBuilder var items: some View { trace("items") {
        ItemsView()
    } }

    @ViewBuilder var foreground: some View { trace("foreground") {
        Color.white.opacity(0.1)
            .modifier(MultipleTouchModifier(model: multipleTouch))
    } }

    @ViewBuilder var canvas: some View { trace("canvas") {
        ZStack {
            background
            items
            foreground
        }
        .sizeReader { global.viewport.setViewSize($0) }
    } }

    @ViewBuilder var overlay: some View { trace("overlay") {
        ZStack {
            ActiveItemView()
            FocusedPathView()

            DraggingSelectionView()
            AddingPathView()

            ContextMenuRoot()

            VStack(spacing: 0) {
                Toolbar()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.top, 20)
                    .zIndex(2)
                ZStack {
                    FloatingPanelRoot()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    PanelPopover()
                }
                .zIndex(1)
                CanvasActionView()
                    .aligned(axis: .horizontal, .start)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .zIndex(0)
            }
        }
        .allowsHitTesting(!multipleTouch.active)
    } }
}

#Preview {
    CanvasView()
}
