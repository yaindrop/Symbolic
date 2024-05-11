import Foundation

enum CanvasAction {
    enum Triggering {
        case longPressViewport

        case longPressPathEdge
    }

    enum Continuous {
        case panViewport
        case pinchViewport

        case dragSelection

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

class CanvasActionModel: ObservableObject {
    @Published var actions: [CanvasAction] = []

    func onStart(triggering: CanvasAction.Triggering) {
        actions.append(.triggering(triggering))
    }

    func onEnd(triggering: CanvasAction.Triggering) {
        actions.removeAll { if case let .triggering(t) = $0 { t == triggering } else { false }}
    }

    func onStart(continuous: CanvasAction.Continuous) {
        actions.append(.continuous(continuous))
    }

    func onEnd(continuous: CanvasAction.Continuous) {
        actions.removeAll { if case let .continuous(c) = $0 { c == continuous } else { false }}
    }

    func on(instant: CanvasAction.Instant) {
        
    }
}
