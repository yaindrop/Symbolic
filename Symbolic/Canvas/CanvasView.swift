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

enum SidebarType: CaseIterable, SelfIdentifiable {
    case document, panel
}

struct SidebarView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var syncUpdate: Bool { true }
        @Selected({ global.panel.movingPanelMap }) var movingPanelMap
        @Selected({ global.panel.sidebarFrame }) var frame
        @Selected({ global.panel.sidebarPanels }) var sidebarPanels
    }

    @SelectorWrapper var selector

    @State private var sidebarType: SidebarType = .document

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension SidebarView {
    var hovering: Bool { selector.movingPanelMap.contains { selector.frame.contains($0.value.globalPosition) } }

    var borderColor: Color { hovering ? .blue : .label.opacity(0.2) }

    @ViewBuilder var content: some View {
        ScrollView {
            if sidebarType == .document {
                documents
            } else {
                panels
            }
        }
    }

    var documents: some View {
        VStack(spacing: 0) {
            Text("No documents")
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(12)
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sidebarType = .panel
                } label: {
                    Image(systemName: "list.dash.header.rectangle")
                }
            }
        }
    }

    var panels: some View {
        VStack(spacing: 0) {
            ForEach(selector.sidebarPanels) {
                $0.view
                    .environment(\.panelId, $0.id)
            }
            Text(selector.movingPanelMap.isEmpty ? "No panels" : "Move panel here")
                .frame(maxWidth: .infinity, minHeight: 120)
                .geometryReader { global.panel.update(sidebarFrame: $0.frame(in: .global)) }
                .if(!selector.movingPanelMap.isEmpty) {
                    $0.clipRounded(radius: 12, border: borderColor, stroke: .init(lineWidth: 2, dash: [8]))
                }
                .padding(12)
        }
        .navigationTitle("Panels")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sidebarType = .document
                } label: {
                    Image(systemName: "doc.text")
                }
            }
        }
    }
}

#Preview {
    CanvasView()
}
