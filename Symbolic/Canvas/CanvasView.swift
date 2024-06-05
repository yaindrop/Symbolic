import Combine
import SwiftUI

// MARK: - CanvasView

struct CanvasView: View {
    @StateObject var multipleTouch = MultipleTouchModel()
    @State var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    // MARK: body

    var body: some View { tracer.range("CanvasView body") {
        navigationView
            .onChange(of: global.activeItem.activePath) {
                let _r = tracer.range("Active path change \(global.activeItem.activePath?.id.uuidString ?? "nil")"); defer { _r() }
                global.activeItem.onActivePathChanged()
            }
            .onAppear {
                let setup = CanvasSetup()
                setup.documentLoad()
                setup.pathUpdate()
                setup.multipleTouch(multipleTouch: multipleTouch)

                pressDetector.subscribe()
                setup.multipleTouchPress(multipleTouchPress: multipleTouchPress)
            }
            .onAppear {
                global.panel.register(align: .bottomTrailing) { ActivePathPanel(panelId: $0) }
                global.panel.register(align: .bottomLeading) { HistoryPanel(panelId: $0) }
                global.panel.register(align: .bottomLeading) { ItemPanel(panelId: $0) }
                global.panel.register(align: .topTrailing) { DebugPanel(panelId: $0, multipleTouch: multipleTouch, multipleTouchPress: multipleTouchPress) }
                global.panel.register(align: .topLeading) { _ in CanvasActionPanel() }
            }
            .onAppear {
                global.contextMenu.register(.pathNode)
                global.contextMenu.register(.focusedPath)
                global.contextMenu.register(.focusedGroup)
                global.contextMenu.register(.selection)
            }
            .onAppear {
                global.document.setDocument(.init(from: fooSvg))
            }
    }}

    // MARK: private

    private var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }

    @State private var longPressPosition: Point2?

    // MARK: view builders

    @ViewBuilder private var navigationView: some View {
        NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
            Text("sidebar")
                .navigationTitle("Sidebar")
        } detail: {
            ZStack {
                canvas
                overlay
            }
            .navigationBarTitleDisplayMode(.inline)
            .clipped()
            .edgesIgnoringSafeArea(.bottom)
            .modifier(ToolbarModifier())
        }
    }

    @ViewBuilder private var background: some View { tracer.range("CanvasView background") {
        Background()
    } }

    @ViewBuilder var items: some View { tracer.range("CanvasView items") {
        ItemsView()
    } }

    @ViewBuilder private var foreground: some View { tracer.range("CanvasView foreground") {
        Color.white.opacity(0.1)
            .modifier(MultipleTouchModifier(model: multipleTouch))
    } }

    @ViewBuilder private var canvas: some View { tracer.range("CanvasView canvas") {
        ZStack {
            background
            items
            foreground
        }
        .sizeReader { global.viewport.setViewSize($0) }
    }}

    @ViewBuilder private var overlay: some View { tracer.range("CanvasView overlay") {
        ZStack {
            ActiveItemView()
            ActivePathView()

            DraggingSelectionView()
            AddingPathView()

            ContextMenuRoot()

            PanelRoot()
        }
        .allowsHitTesting(!multipleTouch.active)
    } }
}

struct ItemsView: View {
    @Selected("ItemsView toView") private var toView = global.viewport.toView
    @Selected("ItemsView allPaths") private var allPaths = global.item.allPaths
    @Selected("ItemsView activePathId") private var activePathId = global.activeItem.focusedItemId

    var body: some View { tracer.range("ItemsView body") {
        ForEach(allPaths.filter { $0.id != activePathId }) { p in
            SUPath { path in p.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
        .transformEffect(toView)
        .blur(radius: 1)
    } }
}

#Preview {
    CanvasView()
}
