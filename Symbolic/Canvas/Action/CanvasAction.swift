import Combine

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

        case movePathNode
        case movePathEdge
        case movePathBezierControl
        case splitAndMovePathNode
    }

    enum Instant {
        case focusPath
        case blurPath
        case focusPathNode
        case blurPathNode
        case focusPathEdge
        case blurPathEdge
    }

    case triggering(Triggering)
    case continuous(Continuous)
    case instant(Instant)
}

class CanvasActionStore: Store {
    @Trackable var triggering = Set<CanvasAction.Triggering>()
    @Trackable var continuous = Set<CanvasAction.Continuous>()
    @Trackable var instant = Set<CanvasAction.Instant>()

    func onStart(triggering action: CanvasAction.Triggering) {
        update { $0(\._triggering, triggering.with { $0.insert(action) }) }
    }

    func onEnd(triggering action: CanvasAction.Triggering) {
        update { $0(\._triggering, triggering.with { $0.remove(action) }) }
    }

    func onStart(continuous action: CanvasAction.Continuous) {
        update { $0(\._continuous, continuous.with { $0.insert(action) }) }
    }

    func onEnd(continuous action: CanvasAction.Continuous) {
        update { $0(\._continuous, continuous.with { $0.remove(action) }) }
    }

    func on(instant action: CanvasAction.Instant) {
        update { $0(\._instant, instant.with { $0.remove(action) }) }
    }

    var subscriptions = Set<AnyCancellable>()
}
