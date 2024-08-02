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
    case auto
    case cubic
    case line
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
        case .auto: "Auto"
        case .cubic: "Cubic"
        case .line: "Line"
        case .quadratic: "Quad"
        }
    }

    func activeType(segment: PathSegment, isOut: Bool) -> Self {
        switch self {
        case .auto:
            let cubic = isOut ? segment.fromCubicOut : segment.toCubicIn
            guard !cubic.isZero else { return .line }
            guard segment.quadratic == nil else { return .quadratic }
            return .cubic
        case .quadratic:
            guard segment.quadratic == nil else { return .quadratic }
            return .cubic
        default:
            return self
        }
    }
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
        segmentTypeMap[id] ?? .auto
    }
}
