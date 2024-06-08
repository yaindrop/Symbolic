import Foundation
import SwiftUI

struct CanvasSetup {
    func pathUpdate() {
        global.documentUpdater.store.pendingEventPublisher
            .sink {
                global.document.setPendingEvent($0)
            }
            .store(in: global.document.store)

        global.documentUpdater.store.eventPublisher
            .sink { e in
                global.document.sendEvent(e)
            }
            .store(in: global.document.store)
    }

    func documentLoad() {
        global.document.store.$activeDocument.didSet
            .sink {
                global.path.loadDocument($0)
                global.pathProperty.loadDocument($0)
                global.item.loadDocument($0)
            }
            .store(in: global.item.store)

        global.document.store.$pendingEvent.didSet
            .sink {
                global.path.loadPendingEvent($0)
                global.pathProperty.loadPendingEvent($0)
                global.item.loadPendingEvent($0)
            }
            .store(in: global.item.store)
    }

    func multipleTouch(multipleTouch: MultipleTouchModel) {
        multipleTouch.$panInfo
            .sink { global.viewportUpdater.onPanInfo($0) }
            .store(in: global.viewportUpdater.store)
        multipleTouch.$pinchInfo
            .sink { global.viewportUpdater.onPinchInfo($0) }
            .store(in: global.viewportUpdater.store)
    }

    func multipleTouchPress(multipleTouchPress: MultipleTouchPressModel) {
        var toolbarMode: ToolbarMode { global.toolbar.mode }
        var toWorld: CGAffineTransform { global.viewport.toWorld }
        var draggingSelectionActive: Bool { global.draggingSelection.active }
        multipleTouchPress.onPress {
            if case .select = toolbarMode {
                global.canvasAction.start(triggering: .select)
            } else if case .addPath = toolbarMode {
                global.canvasAction.start(triggering: .addPath)
            }
        }
        multipleTouchPress.onPressEnd { cancelled in
            global.canvasAction.end(triggering: .select)
            global.canvasAction.end(triggering: .addPath)
            if cancelled {
                global.viewportUpdater.setBlocked(false)
                global.canvasAction.end(continuous: .draggingSelection)
                global.canvasAction.end(continuous: .addingPath)

                global.draggingSelection.cancel()
                global.addingPath.cancel()
            }
        }
        multipleTouchPress.onTap { info in
            let worldLocation = info.location.applying(toWorld)
            let _r = tracer.range(type: .intent, "On tap \(worldLocation)"); defer { _r() }
            let pathId = global.path.hitTest(position: worldLocation)?.id
            if global.toolbar.multiSelect {
                if let pathId {
                    global.activeItem.selectAdd(itemId: pathId)
                } else {
                    global.activeItem.blur()
                }
            } else {
                if let pathId {
                    global.canvasAction.on(instant: .activatePath)
                    global.activeItem.focus(itemId: pathId)
                } else if !global.activeItem.store.activeItemIds.isEmpty {
                    global.canvasAction.on(instant: .deactivatePath)
                    global.activeItem.blur()
                }
            }
        }
        multipleTouchPress.onLongPress { info in
            let worldLocation = info.current.applying(toWorld)
            let _r = tracer.range(type: .intent, "On long press \(worldLocation)"); defer { _r() }

            global.viewportUpdater.setBlocked(true)
            global.canvasAction.end(continuous: .panViewport)

            global.canvasAction.end(triggering: .select)
            global.canvasAction.end(triggering: .addPath)

            if case .select = toolbarMode, !draggingSelectionActive {
                global.canvasAction.start(continuous: .draggingSelection)
                global.draggingSelection.onStart(from: info.current)
            } else if case .addPath = toolbarMode {
                global.canvasAction.start(continuous: .addingPath)
                global.addingPath.onStart(from: info.current)
            }
        }
        multipleTouchPress.onLongPressEnd { _ in
            let _r = tracer.range(type: .intent, "On long press end"); defer { _r() }
            global.viewportUpdater.setBlocked(false)

            global.draggingSelection.onEnd()
            global.canvasAction.end(continuous: .draggingSelection)

            if let path = global.addingPath.addingPath {
                global.documentUpdater.update(path: .create(.init(path: path)))
                global.activeItem.focus(itemId: path.id)
                global.canvasAction.on(instant: .addPath)
            }
            global.addingPath.onEnd()
            global.canvasAction.end(continuous: .addingPath)
        }

        multipleTouchPress.onDrag {
            global.canvasAction.end(triggering: .select)
            global.canvasAction.end(triggering: .addPath)

            global.draggingSelection.onDrag($0)
            global.addingPath.onDrag($0)
        }

        global.draggingSelection.store.$intersectedItems.willUpdate
            .sink {
                global.activeItem.select(itemIds: $0.map { $0.id })
            }
            .store(in: global.draggingSelection.store)
    }
}
