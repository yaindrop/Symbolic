import Foundation

enum PathNodeType {
    case corner
    case locked
    case mirrored
}

enum PathEdgeType {
    case cubic
    case line
    case quadratic
}

struct PathProperty: Equatable {
    let id: UUID
    var name: String?

    var nodeTypeMap: [UUID: PathNodeType]
    var edgeTypeMap: [UUID: PathEdgeType]
}
