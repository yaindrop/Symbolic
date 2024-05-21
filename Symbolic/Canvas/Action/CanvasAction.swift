import Combine
import Foundation

enum CanvasAction {
    enum Triggering {
        case select
        case addPath
        case splitPathEdge
    }

    enum Continuous {
        case panViewport
        case pinchViewport

        case pendingSelection
        case addingPath

        case movePath
        case moveSelection
        case movePathNode
        case movePathEdge
        case movePathBezierControl
        case movePathArcControl
        case splitAndMovePathNode
    }

    enum Instant {
        case activatePath
        case deactivatePath
        case focusPathNode
        case blurPathNode
        case focusPathEdge
        case blurPathEdge

        case selectPaths
        case cancelSelection
        case addPath

        case undo
    }

    case triggering(Triggering)
    case continuous(Continuous)
    case instant(Instant)
}

class CanvasActionStore: Store {
    @Trackable var triggering = Set<CanvasAction.Triggering>()
    @Trackable var continuous = Set<CanvasAction.Continuous>()
    @Trackable var instant = Set<CanvasAction.Instant>()

    func start(triggering action: CanvasAction.Triggering) {
        update { $0(\._triggering, triggering.with { $0.insert(action) }) }
    }

    func end(triggering action: CanvasAction.Triggering) {
        update { $0(\._triggering, triggering.with { $0.remove(action) }) }
    }

    func start(continuous action: CanvasAction.Continuous) {
        update { $0(\._continuous, continuous.with { $0.insert(action) }) }
    }

    func end(continuous action: CanvasAction.Continuous) {
        update { $0(\._continuous, continuous.with { $0.remove(action) }) }
    }

    func on(instant action: CanvasAction.Instant) {
        if instant.contains(action) {
            return
        }
        update { $0(\._instant, instant.with { $0.insert(action) }) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.update { $0(\._instant, self.instant.with { $0.remove(action) }) }
        }
    }

    var subscriptions = Set<AnyCancellable>()
}
