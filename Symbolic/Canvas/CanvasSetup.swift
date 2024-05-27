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
                if global.document.store.pendingEvent != nil {
                    global.document.sendEvent(e)
                } else {
                    withAnimation {
                        global.document.sendEvent(e)
                    }
                }
            }
            .store(in: global.document.store)
    }

    func documentLoad() {
        global.document.store.$activeDocument
            .sink {
                global.path.loadDocument($0)
                global.item.loadDocument($0)
            }
            .store(in: global.item.store)

        global.document.store.$pendingEvent
            .sink {
                global.path.loadPendingEvent($0)
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

        multipleTouch.$panInfo
            .sink { global.pendingSelection.onPan($0) }
            .store(in: global.addingPath.store)

        multipleTouch.$panInfo
            .sink { global.addingPath.onPan($0) }
            .store(in: global.addingPath.store)
    }

    func multipleTouchPress(multipleTouchPress: MultipleTouchPressModel) {
        var toolbarMode: ToolbarMode { global.toolbar.mode }
        var toWorld: CGAffineTransform { global.viewport.toWorld }
        var pendingSelectionActive: Bool { global.pendingSelection.active }
        multipleTouchPress.onPress {
            if case .select = toolbarMode {
                global.canvasAction.start(triggering: .select)
            } else if case .addPath = toolbarMode {
                global.canvasAction.start(triggering: .addPath)
            }
        }
        multipleTouchPress.onPressEnd {
            global.canvasAction.end(triggering: .select)
            global.canvasAction.end(triggering: .addPath)
        }
        multipleTouchPress.onTap { info in
            let worldLocation = info.location.applying(toWorld)
            let _r = tracer.range("On tap \(worldLocation)", type: .intent); defer { _r() }
            withAnimation {
                if !global.selection.selectedPathIds.isEmpty {
                    global.selection.update(pathIds: [])
                    global.canvasAction.on(instant: .cancelSelection)
                }
                if let pathId = global.path.hitTest(worldPosition: worldLocation)?.id {
                    global.canvasAction.on(instant: .activatePath)
                    global.activePath.activate(pathId: pathId)
                } else if global.activePath.activePathId != nil {
                    global.canvasAction.on(instant: .deactivatePath)
                    global.activePath.deactivate()
                }
            }
        }
        multipleTouchPress.onLongPress { info in
            let worldLocation = info.current.applying(toWorld)
            let _r = tracer.range("On long press \(worldLocation)", type: .intent); defer { _r() }

            global.viewportUpdater.setBlocked(true)
            global.canvasAction.end(continuous: .panViewport)

            global.canvasAction.end(triggering: .select)
            global.canvasAction.end(triggering: .addPath)

            if case .select = toolbarMode, !pendingSelectionActive {
                global.canvasAction.start(continuous: .pendingSelection)
                global.pendingSelection.onStart(from: info.current)
            } else if case let .addPath(addPath) = toolbarMode {
                global.canvasAction.start(continuous: .addingPath)
                global.addingPath.onStart(from: info.current)
            }
        }
        multipleTouchPress.onLongPressEnd { _ in
            let _r = tracer.range("On long press end", type: .intent); defer { _r() }
            global.viewportUpdater.setBlocked(false)
            //                    longPressPosition = nil

            let selectedPaths = global.pendingSelection.intersectedPaths
            if !selectedPaths.isEmpty {
                global.selection.update(pathIds: Set(selectedPaths.map { $0.id }))
                global.canvasAction.on(instant: .selectPaths)
            }
            global.pendingSelection.onEnd()
            global.canvasAction.end(continuous: .pendingSelection)

            if let path = global.addingPath.addingPath {
                global.documentUpdater.update(path: .create(.init(path: path)))
                global.activePath.activate(pathId: path.id)
                global.canvasAction.on(instant: .addPath)
            }
            global.addingPath.onEnd()
            global.canvasAction.end(continuous: .addingPath)
        }
    }
}
