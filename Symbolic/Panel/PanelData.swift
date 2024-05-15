import Foundation
import SwiftUI

// MARK: - PanelIdKey

private struct PanelIdKey: EnvironmentKey {
    typealias Value = UUID
    static let defaultValue = UUID()
}

extension EnvironmentValues {
    var panelId: UUID {
        get { self[PanelIdKey.self] }
        set { self[PanelIdKey.self] = newValue }
    }
}

// MARK: - PanelAffinity

enum PanelAffinity {
    struct Root {
        let axis: Axis
        let align: AxisAlign
    }

    struct Peer {
        let peerId: UUID
        let axis: Axis
        let selfAlign: AxisAlign
        let peerAlign: AxisAlign
    }

    case root(Root)
    case peer(Peer)

    var axis: Axis {
        switch self {
        case let .root(root): root.axis
        case let .peer(peer): peer.axis
        }
    }
}

// MARK: CustomStringConvertible

extension PanelAffinity.Root: CustomStringConvertible {
    var description: String { "(\(axis), \(align))" }
}

extension PanelAffinity.Peer: CustomStringConvertible {
    var description: String { "(\(axis), \(selfAlign) to \(peerAlign) of \(peerId)" }
}

extension PanelAffinity: CustomStringConvertible {
    var description: String {
        switch self {
        case let .root(root): "Root\(root.description)"
        case let .peer(peer): "Peer\(peer.description)"
        }
    }
}

// MARK: - PanelData

struct PanelData: Identifiable {
    let id: UUID = UUID()

    let view: AnyView

    var origin: Point2 = .zero
    var size: CGSize = .zero

    var affinities: [PanelAffinity] = []

    var rect: CGRect { .init(origin: origin, size: size) }
}
