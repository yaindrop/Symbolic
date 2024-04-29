import Foundation

enum DocumentAction {
    enum PathHandle {
        case aroundNode
        case aroundEdge
        case bezierControl
        case arcRadius
    }

    enum PathInput {
        case nodePosition
        case bezierControl
        case arcRadius
        case arcRotation
    }

    case pathHandle(PathHandle)
    case pathInput(PathInput)
}
