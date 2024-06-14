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
                global.panel.register(align: .bottomTrailing) { PathPanel(panelId: $0) }
                global.panel.register(align: .bottomLeading) { HistoryPanel(panelId: $0) }
                global.panel.register(align: .bottomLeading) { ItemPanel(panelId: $0) }
                global.panel.register(align: .topTrailing) { DebugPanel(panelId: $0, multipleTouch: multipleTouch, multipleTouchPress: multipleTouchPress) }
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
        NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
            SidebarView()
        } detail: {
            ZStack {
                canvas
                overlay
            }
            .navigationBarTitleDisplayMode(.inline)
            .clipped()
            .edgesIgnoringSafeArea(.bottom)
            .modifier(ToolbarModifier())
            .dropDestination(for: Data.self) { items, location in
                guard let item = items.first else { return false }
                guard let id = UUID(uuidString: String(decoding: item, as: UTF8.self)) else { return false }
                global.panel.drop(panelId: id, location: location)
                return true
            }
        }
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
            CanvasActionView()

            PanelRoot()
        }
        .allowsHitTesting(!multipleTouch.active)
    } }
}

struct SidebarView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var syncUpdate: Bool { true }
        @Selected({ global.panel.movingPanel }) var movingPanel
        @Selected({ global.panel.sidebarFrame }) var frame
        @Selected({ global.panel.sidebarPanels }) var sidebarPanels
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension SidebarView {
    var hovering: Bool { selector.movingPanel.contains { selector.frame.contains($0.value.globalPosition) } }

    var borderColor: Color { hovering ? .blue : .label.opacity(0.2) }

    @ViewBuilder var content: some View {
        ScrollView {
            VStack {
                ForEach(selector.sidebarPanels) {
                    global.panel.panelMap.value(key: $0)?.view($0)
                }
                Text(selector.movingPanel.isEmpty ? "No panels" : "Move panel here")
                    .padding(12)
            }
        }
        .navigationTitle("Sidebar")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .if(!selector.movingPanel.isEmpty) {
            $0.clipRounded(radius: 12, border: borderColor, stroke: .init(lineWidth: 2, dash: [8]))
        }
        .geometryReader { global.panel.update(sidebarFrame: $0.frame(in: .global)) }
        .padding(12)
    }
}

#Preview {
    CanvasView()
}
