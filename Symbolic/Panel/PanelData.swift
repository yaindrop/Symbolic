import Foundation
import SwiftUI

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
}

extension PanelAffinity {
    var root: Root? { if case let .root(v) = self { v } else { nil } }
    var peer: Peer? { if case let .peer(v) = self { v } else { nil } }
}

// MARK: Impl

private protocol PanelAffinityImpl: Equatable {
    var axis: Axis { get }
    func related(to peerId: UUID) -> Bool
}

extension PanelAffinity.Root: PanelAffinityImpl {
    func related(to _: UUID) -> Bool { false }
}

extension PanelAffinity.Peer: PanelAffinityImpl {
    func related(to peerId: UUID) -> Bool { self.peerId == peerId }
}

extension PanelAffinity: PanelAffinityImpl {
    fileprivate typealias Impl = any PanelAffinityImpl

    var axis: Axis { impl.axis }

    func related(to peerId: UUID) -> Bool { impl.related(to: peerId) }

    private var impl: Impl {
        switch self {
        case let .root(root): root
        case let .peer(peer): peer
        }
    }
}

struct PanelAffinityPair: Equatable {
    var horizontal: PanelAffinity?, vertical: PanelAffinity?

    func related(to peerId: UUID) -> Bool {
        horizontal?.related(to: peerId) ?? false || vertical?.related(to: peerId) ?? false
    }

    subscript(axis: Axis) -> PanelAffinity? {
        get { axis == .horizontal ? horizontal : vertical }
        set { if axis == .horizontal { horizontal = newValue } else { vertical = newValue } }
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

struct PanelData: Identifiable, UniqueEquatable {
    let id: UUID = .init()

    let view: (_ panelId: UUID) -> AnyView

    var origin: Point2 = .zero
    var size: CGSize = .zero

    var affinities = PanelAffinityPair()

    var rect: CGRect { .init(origin: origin, size: size) }
}
