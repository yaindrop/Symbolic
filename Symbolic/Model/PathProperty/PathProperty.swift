import Foundation

// MARK: - PathNodeType

enum PathNodeType: Codable, CaseIterable {
    case corner
    case locked
    case mirrored
}

extension PathNodeType {
    var name: String {
        switch self {
        case .corner: "Corner"
        case .locked: "Locked"
        case .mirrored: "Mirrored"
        }
    }

    func map(current: Vector2, opposite: Vector2) -> Vector2 {
        switch self {
        case .corner: current
        case .locked: opposite.with(length: -current.length)
        case .mirrored: -opposite
        }
    }
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

// MARK: - PathSegmentType

enum PathSegmentType: Codable, CaseIterable {
    case cubic
    case quadratic
}

enum PathBezierControlType: Codable {
    case cubicIn
    case cubicOut
    case quadratic
}

extension PathSegmentType {
    var name: String {
        switch self {
        case .cubic: "Cubic"
        case .quadratic: "Quad"
        }
    }

    func activeType(segment: PathSegment) -> Self {
        if self == .quadratic && segment.quadratic != nil {
            return .quadratic
        }
        return .cubic
    }
}

extension PathSegmentType: CustomStringConvertible {
    var description: String {
        switch self {
        case .cubic: "cubic"
        case .quadratic: "quadratic"
        }
    }
}

// MARK: - PathProperty

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
        segmentTypeMap[id] ?? .cubic
    }
}
