import Combine
import SwiftUI

let debugCanvasOverlay: Bool = false

// MARK: - global actions

private extension GlobalStores {
    var canvasGesture: MultipleTouchGesture {
        .init(
            onPress: {
                switch toolbar.mode {
                case .select: canvasAction.start(triggering: .select)
                case .addPath: canvasAction.start(triggering: .addPath)
                }
            },
            onPressEnd: { cancelled in
                canvasAction.end(triggering: .select)
                canvasAction.end(triggering: .addPath)
                if cancelled {
                    viewportUpdater.setBlocked(false)
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
                    hitSymbolId = item.symbolHitTest(position: worldPosition)
                guard let editingSymbolId else {
                    activeSymbol.setFocus(symbolId: hitSymbolId)
                    return
                }
                let hitPathId = item.pathHitTest(position: worldPosition)
                if hitSymbolId != editingSymbolId, hitPathId == nil {
                    activeSymbol.setFocus(symbolId: editingSymbolId)
                    return
                }
                if toolbar.multiSelect {
                    if let hitPathId {
                        activeItem.selectAdd(itemId: hitPathId)
                    } else {
                        activeItem.onTap(itemId: nil)
                    }
                    return
                }
                if let hitPathId {
                    canvasAction.on(instant: .activatePath)
                    activeItem.onTap(itemId: hitPathId)
                } else {
                    canvasAction.on(instant: .deactivatePath)
                    activeItem.onTap(itemId: nil)
                }
            },
            onLongPress: { info in
                let worldPosition = info.current.applying(viewport.viewToWorld)
                let _r = tracer.range(type: .intent, "On long press \(worldPosition)"); defer { _r() }

                viewportUpdater.setBlocked(true)
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
                viewportUpdater.setBlocked(false)

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
            onPan: { viewportUpdater.onPan($0) },
            onPanEnd: { _ in viewportUpdater.onCommit() },
            onPinch: { viewportUpdater.onPinch($0) },
            onPinchEnd: { _ in viewportUpdater.onCommit() }
        )
    }

    func setupDraggingFlow() {
        draggingSelect.store.holdCancellables {
            draggingSelect.store.$intersectedItems.willNotify
                .sink {
                    activeItem.select(itemIds: $0.map { $0.id })
                }
        }

        activeItem.store.holdCancellables {
            activeItem.store.$state.willNotify
                .sink { _ in
                    focusedPath.selectionClear()
                }
        }

        activeSymbol.store.holdCancellables {
            activeSymbol.store.$state.willNotify
                .sink { _ in
                    activeItem.blur()
                }
        }
    }
}

// MARK: - CanvasView

struct CanvasView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.viewportUpdater.store.updating }) var viewportUpdating
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
                    global.panel.register(name: "Items", align: .bottomLeading) { ItemPanel() }
                    global.panel.register(name: "Debug", align: .bottomTrailing) { DebugPanel() }
                    global.panel.register(name: "Grid", align: .bottomTrailing) { GridPanel() }

                    global.contextMenu.clear()
                    global.contextMenu.register(.pathFocusedPart)
                    global.contextMenu.register(.focusedPath)
                    global.contextMenu.register(.focusedGroup)
                    global.contextMenu.register(.selection)
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
            Background()
//            ItemsView()
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
