import Foundation

enum PathNodeType: Codable, CaseIterable {
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

enum PathSegmentType: Codable, CaseIterable {
    case auto
    case cubic
    case line
    case quadratic
}

extension PathSegmentType: CustomStringConvertible {
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
    var segmentTypeMap: [UUID: PathSegmentType] = [:]
}

extension PathProperty {
    func nodeType(id: UUID) -> PathNodeType {
        nodeTypeMap[id] ?? .corner
    }

    func segmentType(id: UUID) -> PathSegmentType {
        segmentTypeMap[id] ?? .auto
    }
}
