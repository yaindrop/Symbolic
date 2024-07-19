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
                    canvasAction.end(continuous: .draggingSelection)
                    canvasAction.end(continuous: .addingPath)

                    draggingSelection.cancel()
                    addingPath.cancel()
                }
            },
            onTap: { info in
                let worldLocation = info.location.applying(viewport.toWorld)
                let _r = tracer.range(type: .intent, "On tap \(worldLocation)"); defer { _r() }
                let pathId = path.hitTest(position: worldLocation)?.id
                if toolbar.multiSelect {
                    if let pathId {
                        activeItem.selectAdd(itemId: pathId)
                    } else {
                        activeItem.blur()
                    }
                } else {
                    if let pathId {
                        canvasAction.on(instant: .activatePath)
                        activeItem.focus(itemId: pathId)
                    } else if !activeItem.store.activeItemIds.isEmpty {
                        canvasAction.on(instant: .deactivatePath)
                        activeItem.blur()
                    }
                }
            },
            onLongPress: { info in
                let worldLocation = info.current.applying(viewport.toWorld)
                let _r = tracer.range(type: .intent, "On long press \(worldLocation)"); defer { _r() }

                viewportUpdater.setBlocked(true)
                canvasAction.end(continuous: .panViewport)

                canvasAction.end(triggering: .select)
                canvasAction.end(triggering: .addPath)

                switch toolbar.mode {
                case .select:
                    if !draggingSelection.active {
                        canvasAction.start(continuous: .draggingSelection)
                        draggingSelection.onStart(from: info.current)
                    }
                case .addPath:
                    if !addingPath.active {
                        canvasAction.start(continuous: .addingPath)
                        addingPath.onStart(from: info.current)
                    }
                }
            },
            onLongPressEnd: { _ in
                let _r = tracer.range(type: .intent, "On long press end"); defer { _r() }
                viewportUpdater.setBlocked(false)

                draggingSelection.onEnd()
                canvasAction.end(continuous: .draggingSelection)

                if let path = addingPath.polyline {
                    documentUpdater.update(path: .create(.init(path: path)))
                    activeItem.focus(itemId: path.id)
                    canvasAction.on(instant: .addPath)
                }
                addingPath.onEnd()
                canvasAction.end(continuous: .addingPath)
            },
            onDrag: {
                canvasAction.end(triggering: .select)
                canvasAction.end(triggering: .addPath)

                draggingSelection.onDrag($0)
                addingPath.onDrag($0)
            },
            onPan: { viewportUpdater.onPan($0) },
            onPanEnd: { _ in viewportUpdater.onCommit() },
            onPinch: { viewportUpdater.onPinch($0) },
            onPinchEnd: { _ in viewportUpdater.onCommit() }
        )
    }

    func setupDraggingFlow() {
        draggingSelection.store.holdCancellables {
            draggingSelection.store.$intersectedItems.willNotify
                .sink {
                    activeItem.select(itemIds: $0.map { $0.id })
                }
        }

        activeItem.store.holdCancellables {
            activeItem.store.$focusedItemId.willNotify
                .sink { _ in
                    focusedPath.clear()
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
            ItemsView()
        }
        .multipleTouchGesture(global.canvasGesture)
    } }

    @ViewBuilder var activeObjects: some View { trace("activeObjects") {
        ZStack {
            ActiveItemView()
            FocusedPathView()

            DraggingSelectionView()
            AddingPathView()
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
        }
    } }
}

#Preview {
    CanvasView()
}
