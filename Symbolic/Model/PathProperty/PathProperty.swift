import Foundation

enum PathNodeType: Codable {
    case corner
    case locked
    case mirrored
}

extension PathNodeType: CustomStringConvertible {
    var description: String {
        switch self {
        case .corner: "corner"
        case .locked: "locked"
        case .mirrored: "mirrored"
        }
    }
}

enum PathEdgeType: Codable {
    case auto
    case cubic
    case line
    case quadratic
}

extension PathEdgeType: CustomStringConvertible {
    var description: String {
        switch self {
        case .auto: "auto"
        case .cubic: "cubic"
        case .line: "line"
        case .quadratic: "quadratic"
        }
    }
}

struct PathProperty: Identifiable, Equatable, Codable, TriviallyCloneable {
    let id: UUID
    var name: String?

    var nodeTypeMap: [UUID: PathNodeType] = [:]
    var edgeTypeMap: [UUID: PathEdgeType] = [:]
}

extension PathProperty {
    func nodeType(id: UUID) -> PathNodeType {
        nodeTypeMap[id] ?? .corner
    }

    func edgeType(id: UUID) -> PathEdgeType {
        edgeTypeMap[id] ?? .auto
    }
}
