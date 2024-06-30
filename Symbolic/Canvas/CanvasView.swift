import Combine
import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func setupViewportFlow(multipleTouch: MultipleTouchModel) {
        viewportUpdater.store.holdCancellables {
            multipleTouch.$panInfo
                .sink { viewportUpdater.onPanInfo($0) }
            multipleTouch.$pinchInfo
                .sink { viewportUpdater.onPinchInfo($0) }
        }
    }

    func setupMultipleTouchPress(_ multipleTouchPress: MultipleTouchPressModel) {
        var toolbarMode: ToolbarMode { toolbar.mode }
        var toWorld: CGAffineTransform { viewport.toWorld }
        var draggingSelectionActive: Bool { draggingSelection.active }
        multipleTouchPress.onPress {
            if case .select = toolbarMode {
                canvasAction.start(triggering: .select)
            } else if case .addPath = toolbarMode {
                canvasAction.start(triggering: .addPath)
            }
        }
        multipleTouchPress.onPressEnd { cancelled in
            canvasAction.end(triggering: .select)
            canvasAction.end(triggering: .addPath)
            if cancelled {
                viewportUpdater.setBlocked(false)
                canvasAction.end(continuous: .draggingSelection)
                canvasAction.end(continuous: .addingPath)

                draggingSelection.cancel()
                addingPath.cancel()
            }
        }
        multipleTouchPress.onTap { info in
            let worldLocation = info.location.applying(toWorld)
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
        }
        multipleTouchPress.onLongPress { info in
            let worldLocation = info.current.applying(toWorld)
            let _r = tracer.range(type: .intent, "On long press \(worldLocation)"); defer { _r() }

            viewportUpdater.setBlocked(true)
            canvasAction.end(continuous: .panViewport)

            canvasAction.end(triggering: .select)
            canvasAction.end(triggering: .addPath)

            if case .select = toolbarMode, !draggingSelectionActive {
                canvasAction.start(continuous: .draggingSelection)
                draggingSelection.onStart(from: info.current)
            } else if case .addPath = toolbarMode {
                canvasAction.start(continuous: .addingPath)
                addingPath.onStart(from: info.current)
            }
        }
        multipleTouchPress.onLongPressEnd { _ in
            let _r = tracer.range(type: .intent, "On long press end"); defer { _r() }
            viewportUpdater.setBlocked(false)

            draggingSelection.onEnd()
            canvasAction.end(continuous: .draggingSelection)

            if let path = addingPath.addingPath {
                documentUpdater.update(path: .create(.init(path: path)))
                activeItem.focus(itemId: path.id)
                canvasAction.on(instant: .addPath)
            }
            addingPath.onEnd()
            canvasAction.end(continuous: .addingPath)
        }

        multipleTouchPress.onDrag {
            canvasAction.end(triggering: .select)
            canvasAction.end(triggering: .addPath)

            draggingSelection.onDrag($0)
            addingPath.onDrag($0)
        }

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

struct CanvasView: View, TracedView {
    @State var multipleTouch = MultipleTouchModel()
    @State var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    @State private var longPressPosition: Point2?

    var body: some View { trace {
        content
            .onAppear {
                global.setupViewportFlow(multipleTouch: multipleTouch)

                pressDetector.subscribe()
                global.setupMultipleTouchPress(multipleTouchPress)
            }
            .onAppear {
                global.panel.clear()
                global.panel.register(align: .bottomTrailing) { PathPanel() }
                global.panel.register(align: .bottomLeading) { HistoryPanel() }
                global.panel.register(align: .bottomLeading) { ItemPanel() }
                global.panel.register(align: .topTrailing) { DebugPanel(multipleTouch: multipleTouch, multipleTouchPress: multipleTouchPress) }
            }
            .onAppear {
                global.contextMenu.clear()
                global.contextMenu.register(.pathFocusedPart)
                global.contextMenu.register(.focusedPath)
                global.contextMenu.register(.focusedGroup)
                global.contextMenu.register(.selection)
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
