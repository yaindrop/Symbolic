import Combine
import SwiftUI

// MARK: - CanvasView

struct CanvasView: View {
    @State var multipleTouch = MultipleTouchModel()
    @State var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    @StateObject var panelModel = PanelModel()

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
                panelModel.register(align: .bottomTrailing) { ActivePathPanel() }
                panelModel.register(align: .bottomLeading) { HistoryPanel() }
                panelModel.register(align: .bottomLeading) { ItemPanel() }
                panelModel.register(align: .topTrailing) { DebugPanel(multipleTouch: multipleTouch, multipleTouchPress: multipleTouchPress) }
                panelModel.register(align: .topLeading) { CanvasActionPanel() }
            }
            .onAppear {
                global.document.setDocument(.init(from: fooSvg))
            }
    }}

    // MARK: private

    @Selected private var toView = global.viewport.toView
    @Selected private var allPaths = global.item.allPaths
    @Selected private var activePathId = global.activeItem.focusedItemId

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

    @ViewBuilder var items: some View { tracer.range("CanvasView inactivePaths") {
        ForEach(allPaths.filter { $0.id != activePathId }) { p in
            SUPath { path in p.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
        .transformEffect(toView)
        .blur(radius: 1)
    } }

    @ViewBuilder private var foreground: some View { tracer.range("CanvasView foreground") {
        Color.white.opacity(0.1)
            .modifier(MultipleTouchModifier(model: $multipleTouch))
    } }

    @ViewBuilder private var canvas: some View { tracer.range("CanvasView canvas") {
        ZStack {
            background
            items
            foreground
        }
        .viewSizeReader { global.viewport.setViewSize($0) }
    }}

    @ViewBuilder private var overlay: some View { tracer.range("CanvasView overlay") {
        ZStack {
            ActiveItemView()
            ActivePathView()
            PendingSelection()
            SelectionView()
            AddingPath()
            PanelRoot()
                .environmentObject(panelModel)
        }
        .allowsHitTesting(!multipleTouch.active)
    } }
}

#Preview {
    CanvasView()
}
