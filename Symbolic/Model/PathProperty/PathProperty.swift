import Foundation

enum PathNodeType: Encodable {
    case corner
    case locked
    case mirrored
}

enum PathEdgeType: Encodable {
    case cubic
    case line
    case quadratic
}

struct PathProperty: Identifiable, Equatable, Encodable, TriviallyCloneable {
    let id: UUID
    var name: String?

    var nodeTypeMap: [UUID: PathNodeType] = [:]
    var edgeTypeMap: [UUID: PathEdgeType] = [:]
}
