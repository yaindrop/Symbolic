import Combine
import SwiftUI

let debugCanvasOverlay: Bool = false

// MARK: - global actions

private extension GlobalStores {
    func commitViewportUpdate() {
        canvasAction.end(continuous: .panViewport)
        canvasAction.end(continuous: .pinchViewport)
        viewportUpdater.onCommit()
    }

    var canvasGesture: MultipleTouchGesture {
        .init(
            configs: .init(enableTouchDebugView: true),
            onPress: { _ in
                switch toolbar.mode {
                case .select: canvasAction.start(triggering: .select)
                case .addPath: canvasAction.start(triggering: .addPath)
                }
            },
            onPressEnd: { cancelled in
                canvasAction.end(triggering: .select)
                canvasAction.end(triggering: .addPath)
                if cancelled {
                    canvasAction.end(continuous: .draggingSelect)
                    canvasAction.end(continuous: .draggingCreate)

                    draggingSelect.cancel()
                    draggingCreate.cancel()
                }
            },
            onTap: { info in
                let worldPosition = info.location.applying(viewport.viewToWorld)
                let _r = tracer.range(type: .intent, "On tap \(worldPosition)"); defer { _r() }
                let editingSymbolId = activeSymbol.editingSymbolId,
                    hitSymbolId = symbol.symbolHitTest(worldPosition: worldPosition)
                guard let editingSymbolId else {
                    if let hitSymbolId {
                        if activeSymbol.focusedSymbolId == hitSymbolId {
                            activeSymbol.edit(id: hitSymbolId)
                            viewportUpdater.zoomToEditingSymbol()
                        } else {
                            activeSymbol.focus(id: hitSymbolId)
                        }
                    } else {
                        activeSymbol.blur()
                    }
                    return
                }
                let hitPathId = activeSymbol.pathHitTest(worldPosition: worldPosition)
                if hitSymbolId != editingSymbolId, hitPathId == nil {
                    activeSymbol.focus(id: editingSymbolId)
                    return
                }
                if toolbar.multiSelect {
                    if let hitPathId {
                        activeItem.selectAdd(itemId: hitPathId)
                    } else {
                        activeItem.onTap(id: nil)
                    }
                    return
                }
                if let hitPathId {
                    canvasAction.on(instant: .activatePath)
                    activeItem.onTap(id: hitPathId)
                } else {
                    canvasAction.on(instant: .deactivatePath)
                    activeItem.onTap(id: nil)
                }
            },
            onLongPress: { info in
                let worldPosition = info.current.applying(viewport.viewToWorld)
                let _r = tracer.range(type: .intent, "On long press \(worldPosition)"); defer { _r() }

                canvasAction.end(continuous: .panViewport)

                canvasAction.end(triggering: .select)
                canvasAction.end(triggering: .addPath)

                switch toolbar.mode {
                case .select:
                    if !draggingSelect.active {
                        canvasAction.start(continuous: .draggingSelect)
                        draggingSelect.onStart(from: info.current)
                    }
                case .addPath:
                    if !draggingCreate.active {
                        canvasAction.start(continuous: .draggingCreate)
                        draggingCreate.onStart(from: info.current)
                    }
                }
            },
            onLongPressEnd: { _ in
                let _r = tracer.range(type: .intent, "On long press end"); defer { _r() }

                draggingSelect.onEnd()
                canvasAction.end(continuous: .draggingSelect)

                draggingCreate.onEnd()
                canvasAction.end(continuous: .draggingCreate)
            },
            onDrag: {
                canvasAction.end(triggering: .select)
                canvasAction.end(triggering: .addPath)

                draggingSelect.onDrag($0)
                draggingCreate.onDrag($0)
            },
            onPan: {
                if viewportUpdater.blocked {
                    commitViewportUpdate()
                } else {
                    canvasAction.end(continuous: .pinchViewport)
                    canvasAction.start(continuous: .panViewport)
                    viewportUpdater.onPan($0)
                }
            },
            onPanEnd: { _ in commitViewportUpdate() },
            onPinch: {
                if viewportUpdater.blocked {
                    commitViewportUpdate()
                } else {
                    canvasAction.end(continuous: .panViewport)
                    canvasAction.start(continuous: .pinchViewport)
                    viewportUpdater.onPinch($0)
                }
            },
            onPinchEnd: { _ in commitViewportUpdate() }
        )
    }

    func setupDraggingFlow() {
        draggingSelect.store.holdCancellables {
            $0.$symbolIds
                .sink {
                    activeSymbol.select(symbolIds: $0)
                }
            $0.$itemIds
                .sink {
                    activeItem.select(itemIds: $0)
                }
        }

        draggingCreate.store.holdCancellables {
            $0.$symbolRect
                .sink {
                    let newSymbolId = UUID()
                    documentUpdater.update(symbol: .create(.init(symbolId: newSymbolId, origin: $0.origin, size: $0.size)))
                    activeSymbol.focus(id: newSymbolId)
                    canvasAction.on(instant: .addSymbol)
                }
            $0.$path
                .sink {
                    guard let editingSymbolId = activeSymbol.editingSymbolId else { return }
                    let newPathId = UUID()
                    documentUpdater.update(path: .create(.init(symbolId: editingSymbolId, pathId: newPathId, path: $0)))
                    activeItem.focus(id: newPathId)
                    canvasAction.on(instant: .addPath)
                }
        }

        activeItem.store.holdCancellables {
            $0.$state.willNotify
                .sink { _ in
                    focusedPath.selectionClear()
                }
        }

        activeSymbol.store.holdCancellables {
            $0.$state.willNotify
                .sink { _ in
                    activeItem.blur()
                    activeSymbol.setGridIndex(0)
                }
        }
    }
}

// MARK: - CanvasView

struct CanvasView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.viewportUpdater.updating }) var viewportUpdating
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
                .onAppear {
                    global.setupDraggingFlow()

                    global.panel.clear()
                    global.panel.register(name: "Path", align: .bottomTrailing) { PathPanel() }
                    global.panel.register(name: "History", align: .bottomLeading) { HistoryPanel() }
                    global.panel.register(name: "Symbol", align: .bottomLeading) { SymbolPanel() }
                    global.panel.register(name: "Debug", align: .bottomTrailing) { DebugPanel() }
                    global.panel.register(name: "Grid", align: .bottomTrailing) { GridPanel() }
                    global.panel.register(name: "Document", align: .bottomTrailing) { DocumentPanel() }
                }
                .persistentSystemOverlays(.hidden)
        }
    }}
}

// MARK: private

private extension CanvasView {
    @ViewBuilder var content: some View { trace("content") {
        ZStack {
            staticObjects
            activeObjects
            overlay
        }
        .clipped()
        .sizeReader { global.viewport.setViewSize($0) }
        .edgesIgnoringSafeArea(.all)
        .toolbar(.hidden)
    } }

    @ViewBuilder var staticObjects: some View { trace("staticObjects") {
        ZStack {
            GridRoot()
            SymbolsView()
        }
        .multipleTouchGesture(global.canvasGesture)
    } }

    @ViewBuilder var activeObjects: some View { trace("activeObjects") {
        ZStack {
            ActiveSymbolView()
            ActiveItemView()
            FocusedPathView()

            DraggingSelectView()
            DraggingCreateView()
        }
        .allowsHitTesting(!selector.viewportUpdating)
    } }

    @ViewBuilder var overlay: some View { trace("overlay") {
        ZStack {
            ContextMenuRoot()

            VStack(spacing: 0) {
                Toolbar()
                    .zIndex(2)
                ZStack {
                    FloatingPanelRoot()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    PanelPopover()
                }
                .zIndex(1)
                CanvasActionView()
                    .zIndex(0)
            }

            PortalRoot()
        }
    } }
}

#Preview {
    CanvasView()
}
