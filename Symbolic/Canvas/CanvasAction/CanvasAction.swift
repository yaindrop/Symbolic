import Foundation

enum CanvasAction: Equatable {
    enum Triggering: Equatable {
        case select
        case addPath
        case addEndingNode
        case splitPathSegment
    }

    enum Continuous: Equatable {
        case panViewport
        case pinchViewport

        case draggingSelection
        case addingPath

        case movePath
        case moveSelection
        case movePathNode
        case movePathSegment
        case movePathBezierControl
        case movePathArcControl

        case addAndMoveEndingNode
        case splitAndMovePathNode
    }

    enum Instant: Equatable {
        case activatePath
        case deactivatePath
        case focusPathNode
        case blurPathNode
        case focusPathSegment
        case blurPathSegment

        case selectPaths
        case cancelSelection
        case addPath

        case undo
    }

    case triggering(Triggering)
    case continuous(Continuous)
    case instant(Instant)
}

extension CanvasAction.Triggering {
    var hint: String {
        switch self {
        case .addPath: "Hold to add path"
        case .select: "Hold to select"

        case .addEndingNode: "Hold to add node"
        case .splitPathSegment: "Hold to split"
        }
    }
}

extension CanvasAction.Continuous {
    var hint: String {
        switch self {
        case .panViewport: "Move"
        case .pinchViewport: "Move and scale"

        case .addingPath: "Drag to add path"
        case .draggingSelection: "Drag to select"

        case .movePath: "Drag to move path"
        case .moveSelection: "Drag to move selection"
        case .movePathNode: "Drag to move node"
        case .movePathSegment: "Drag to move segment"
        case .movePathBezierControl: "Drag to move control"
        case .movePathArcControl: "Drag to move control"

        case .addAndMoveEndingNode: "Drag to move added node"
        case .splitAndMovePathNode: "Drag to move split node"
        }
    }
}

extension CanvasAction.Instant {
    var hint: String {
        switch self {
        case .activatePath: "Focus path"
        case .deactivatePath: "Unfocus path"
        case .focusPathNode: "Focus node"
        case .blurPathNode: "Unfocus node"
        case .focusPathSegment: "Focus segment"
        case .blurPathSegment: "Unfocus segment"

        case .selectPaths: "Select paths"
        case .cancelSelection: "Cancel selection"
        case .addPath: "Add path"

        case .undo: "Undo"
        }
    }
}
