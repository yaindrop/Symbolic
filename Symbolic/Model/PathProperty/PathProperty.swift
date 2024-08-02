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

enum PathBezierHandleType {
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
        if self == .auto {
            let cubicControl = isOut ? segment.fromControlOut : segment.toControlIn
            if cubicControl == .zero {
                return .line
            }
            if segment.quadratic != nil {
                return .quadratic
            }
            return .cubic
        }
        if self == .quadratic && segment.quadratic == nil {
            return .cubic
        }
        return self
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
