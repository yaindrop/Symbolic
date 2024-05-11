import Foundation

enum PreAction {
    case longPressViewport

    case longPressPathEdge
}

enum ContinuousAction {
    case panViewport
    case pinchViewport
    case dragSelection

    case movePathNode
    case movePathEdge
    case movePathBezierControl
    case splitAndMovePathNode
}

enum InstantAction {
    case focusPath
    case blurPath
    case focusPathNode
    case blurPathNode
    case focusPathEdge
    case blurPathEdge
}
